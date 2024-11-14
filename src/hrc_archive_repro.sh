#! /bin/bash

set -e
set -o pipefail

[ $# -eq 2 ] || {
    echo "Usage: $0 indir outdir" 2>&1
    exit 1
}

indir="$1"
outdir="$2"

mkdir -p "$outdir"

. ~/.bash_aliases
shopt -s expand_aliases nocasematch

#
# CIAO init doesn't work with bash nounset mode
#
reset_u=0
[[ $- =~ u ]] && {
    set +u
    reset_u=1
}
ciao
[ $reset_u -eq 1 ] && set -u

SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

. $SCRIPTDIR/tmppdir.sh
. $SCRIPTDIR/hrc_archive_repro_functions.sh
punlearn ardlib

#
# Use the fov1 file just because it seems to be the smallest available
# data product.
#
fov1=$(get_fov1 "$indir")
detnam=$(dmkeypar "$fov1" detnam ec+)
obsid=$(printf %05d $(dmkeypar "$fov1" obs_id ec+))

[[ $detnam =~ hrc-[is] ]] ||
{
  echo "This script only handles HRC data." 1>&2
  exit 1
}

#
# Decompress original evt1 since it'll be run through
# hrc_process_events multiple times. The decompressed file can be
# deleted at the end of the script.
#
# If the original evt1 is not compressed, then copy it, since
# {ra,dec,roll}_nom will be modified later.
#
evt1_old=$(get_evt1 "$indir")
evt1_old_tmp="$outdir/"$(basename "$evt1_old" | sed s/.gz$//).tmp
[[ "$evt1_old" =~ .gz$ ]] && {
    gzip -dc "$evt1_old" > "$evt1_old_tmp"
} || {
    \cp "$evt1_old" "$evt1_old_tmp"
}
evt1_old="$evt1_old_tmp"

#
# Boresight correction to the aspect solution.
#
asol1_stack=$(asol_stack "$indir/primary")
asol1="$outdir/${obsid}_asol1.fits"
tstart=$(dmkeypar "$fov1" tstart ec+)
tstop=$(dmkeypar "$fov1" tstop ec+)
punlearn dmmerge
dmmerge "$asol1_stack[time=${tstart}:${tstop}]" "$asol1" cl+
asp_offaxis_corr "$asol1" hrc
dmhedit "$asol1" file="" op=add key=CONTENT value=ASPSOLOBI

#
# Generate an observation parameter file containing the aspect
# solution boresight correction information.
#
obs_par=${asol1/asol1.fits/obs.par}
python "$SCRIPTDIR"/make_par "$evt1_old" "$asol1" "$obs_par"

#
# Ensure RANGELEV and WIDTHRES are correct
#
rangelev_widthres_set "$evt1_old"

#
# Create a new badpix file.
#
bpix1=${asol1/asol/bpix}
punlearn hrc_build_badpix
hrc_build_badpix CALDB "$bpix1" "$obs_par" degapfile=CALDB cl+

#
# Usual hpe run.
#
evt1=${bpix1/bpix/evt}
punlearn hrc_process_events
hrc_process_events \
    infile="$evt1_old" \
    outfile="$evt1" \
    badpixfile="$bpix1" \
    acaofffile="$asol1" \
    badfile=NONE \
    do_amp_sf_cor=yes \
    obsfile="$obs_par" \
    $(gainfile_cases $obsid) \
    cl+
r4_header_update "$evt1"


#
# Now create a new evt1 file with unrolled sky coordinates.
#
evt1_deroll=${evt1/evt1/deroll_evt1}
asol1_deroll=${asol1/asol/deroll_asol}
[[ $(hostname) =~ (legs|milagro) ]] || {
    #
    # deroll_asol returns an error code when {ra,dec,roll}_nom
    # keywords are absent frrm the asol1 file. This should not be fatal
    # to the parent bash process if it was run with -e.
    #
    reset_e=0
    [[ $- =~ e ]] && {
	set +e
	reset_e=1
    }
    #
    # mst_envs modifies the path, so keep it isolated
    #
    bash -c '
      . /proj/axaf/simul/etc/mst_envs.sh
      /proj/axaf/simul/bin/deroll_asol --input '"$asol1"' --output '"$asol1_deroll"
    [ $reset_e -eq 1 ] && set -e
}

dmhedit "$evt1_old" filelist=none operation=add key=RA_NOM value=0.0
dmhedit "$evt1_old" filelist=none operation=add key=DEC_NOM value=0.0
dmhedit "$evt1_old" filelist=none operation=add key=ROLL_NOM value=0.0

obs_par_deroll=${obs_par/obs/deroll_obs}
python "$SCRIPTDIR"/make_par "$evt1_old" "$asol1_deroll" "$obs_par_deroll"

pset "$obs_par_deroll" ra_nom=0
pset "$obs_par_deroll" dec_nom=0
pset "$obs_par_deroll" roll_nom=0

punlearn hrc_process_events
hrc_process_events \
    infile="$evt1_old" \
    outfile="$evt1_deroll" \
    badpixfile="$bpix1" \
    acaofffile="$asol1_deroll" \
    badfile=NONE \
    do_amp_sf_cor=yes \
    obsfile="$obs_par_deroll" \
    $(gainfile_cases $obsid) \
    cl+
r4_header_update "$evt1_deroll"

#
# PI filter
#
#dmcopy "$evt1[pi=0:300]" "$evt1".tmp cl+
#\mv "$evt1".tmp "$evt1"
#dmcopy "$evt1_deroll[pi=0:300]" "$evt1_deroll".tmp cl+
#\mv "$evt1_deroll".tmp "$evt1_deroll"

#
# status bit filter
#
[[ $detnam =~ hrc-s* ]] && {
    filter='xxxxxx00xxxx0xxx0000x000x00000xx'
    order_list='-1,1,-2,2,-3,3'
} || {
    filter='xxxxxx00xxxx0xxx00000000x0000000'
    order_list='-1,1'
}

flt_evt1=${evt1/evt1/flt_evt1}
dmcopy "${evt1}[status=$filter]" "$flt_evt1" cl+
flt_evt1_deroll=${evt1/evt1/flt_evt1_deroll}
dmcopy "${evt1_deroll}[status=$filter]" "$flt_evt1_deroll" cl+

#
# GTI filter
#
flt1=$(get_flt1 "$indir")
evt2=${evt1/evt1/evt2}
dmcopy "$flt_evt1[events][@${flt1}]" "$evt2" cl+
evt2_deroll=${evt1/evt1/deroll_evt2}
dmcopy "$flt_evt1_deroll[events][@${flt1}]" "$evt2_deroll" cl+

#
# correct LIVETIME, EXPOSURE, DTCOR
#
dtfstats=${evt1/evt1/dtfstats}
dtf1=$(get_dtf1 "$indir")
hrc_dtf_corr "$dtf1" "$evt2" "$dtfstats"

#
# Pull out unrolled sky coordinates. Columns must be reordered to
# remove the sky vector, so that they can later be merged with the
# evt2{,a}.
#
punlearn dmcopy
dmcopy \
    infile="$evt2_deroll[cols y2=y,x2=x]" \
    outfile="${evt2_deroll}.tmp" \
    cl+

grating=$(pquery "$obs_par" grating)

[[ "$grating" =~ [lh]etg ]] && {
    #
    # get source coordinates...
    #
    ra=$(dmkeypar "$evt2" ra_targ ec+)
    dec=$(dmkeypar "$evt2" dec_targ ec+)
    punlearn dmcoords
    dmcoords \
	infile="$evt2" \
	asolfile="$asol1" \
	option=cel \
	celfmt=deg \
	ra="$ra" \
	dec="$dec" \
	verbose=1
    x=$(pget dmcoords x)
    y=$(pget dmcoords y)

    #
    # ...to pass along to tgdetect2
    #
    src2a=${evt1/evt1/evt1_src2a}
    punlearn tgdetect2
    tgdetect2 \
	infile="$evt2" \
	outfile="$src2a" \
	zo_pos_x="$x" zo_pos_y="$y" \
	cl+

    L2a=${evt1/evt1/evt2_L1a}
    punlearn tg_create_mask
    tg_create_mask \
	infile="$evt2" \
	outfile="$L2a" \
	input_pos_tab="$src2a" \
	grating_obs=header_value \
	cl+

    #
    # Pull out celestial coordinates, so they can be merged into the
    # output of tg_resolve_events.
    #
    evt2_coords=${evt1/evt1/evt2_coords}
    punlearn dmcopy
    dmcopy \
	infile="$evt2[cols ra,dec]" \
	outfile="${evt2_coords}" \
	cl+

    evt2a=${evt1/evt1/evt2a}
    punlearn tg_resolve_events
    tg_resolve_events \
	infile="$evt2" \
	outfile="$evt2a" \
	regionfile="$L2a" \
	eventdef=')stdlev1_HRC' \
	acaofffile="$asol1" \
	osipfile=none \
	cl+

    #
    # paste the celestion and deroll coordinates
    #

    punlearn dmpaste
    dmpaste "${evt2a}" "${evt2_coords}[col ra,dec]" "${evt2a}.tmp" cl+
    \mv "${evt2a}.tmp" "${evt2a}"

    punlearn dmpaste
    dmpaste "${evt2a}" "${evt2_deroll}.tmp[col x2,y2]" "${evt2a}.tmp" cl+
    \mv "${evt2a}.tmp" "${evt2a}"

    #
    # (tg_mlam, pi) filter
    #
    [[ $detnam =~ hrc-s ]] && {
	pireg=$(calquiz infile="$evt2a" product=tgpimask2 calfile=CALDB echo+)
	[ -z "$pireg" ] || {
	    dmcopy "$evt2a[events][(tg_mlam,pi)=region(${pireg})]" "$evt2a".tmp cl+
	    \mv "$evt2a".tmp "$evt2a"
	}
    }

    #
    # append the REGION extension
    #
    punlearn dmappend
    dmappend "$L2a" "$evt2a"

    pha2=${evt1/evt1/pha2}
    punlearn tgextract
    tgextract \
	infile="$evt2a" \
	outfile="$pha2" \
	outfile_type=pha_typeII \
	tg_srcid_list=all \
	tg_part_list=header_value \
	inregion_file=CALDB \
	tg_order_list="$order_list" \
	ancrfile=none \
	respfile=none \
	clobber=yes

    make_response

    \rm -f \
	"$evt2_coords" \
	"$src2a" \
	"$L2a" \
	"$evt2"
} || {
    punlearn dmpaste
    dmpaste "${evt2}" "${evt2_deroll}.tmp[col x2,y2]" "${evt2}.tmp" cl+
    \mv "${evt2}.tmp" "${evt2}"
}


\rm -f \
    "$evt1_old" \
    "$asol1" \
    "$bpix1" \
    "$obs_par" \
    "$evt1" \
    "$obs_par_deroll" \
    "$evt1_deroll" \
    "$flt_evt1" \
    "$flt_evt1_deroll" \
    "$evt2_deroll" \
    "${evt2_deroll}.tmp" \
    "$dtfstats"
#false && [[ $(hostname) =~ (legs|milagro) ]] || rm -f "$asol1_deroll"
