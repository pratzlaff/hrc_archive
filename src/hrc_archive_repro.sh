#! /bin/bash

umask 002

set -eo pipefail

[ $# -eq 2 ] || {
    \echo "Usage: $0 obsid archivedir" >&2
    exit 1
}

obsid=$(printf %05d $(sed 's/^0*//' <<< "$1"))
archivedir="$2"

outdir="$archivedir"

SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

. "$SCRIPTDIR"/hrc_archive_repro_functions.sh

cleanup_files() {
    cmd='\rm -f \
	"$evt1_old" \
	"$obs_par" \
	"$evt1" \
	"$obs_par_deroll" \
	"$evt1_deroll" \
	"$flt_evt1" \
	"$flt_evt1_deroll" \
	"$evt2_deroll" \
	"$evt2_bary" \
        "$evt1_tailgate" \
	"$flt1_ssc" \
	"$dtfstats" \
	"$src2a" \
	"$L2a"'
    [[ ! $obsid =~ 28377|28427 ]] && cmd+=' "$bpix1" "$dtf1" '
    eval "$cmd"
}

\rm -rf "$outdir/incomplete/$obsid"
mkdir -p "$outdir/incomplete/$obsid"
download_data $obsid "$outdir/incomplete/$obsid" || {
    echo "FIXME: download_data $obsid '$outdir/incomplete/$obsid' failed, exiting." 1>&2
    exit
}

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

. "$SCRIPTDIR"/tmppdir.sh

punlearn ardlib

dtf1=$(get_dtf1 "$outdir/incomplete/$obsid")
[ -z "$dtf1" ] && {
    \echo "FIXME: NO DTF1 FOUND IN '$dname', exiting." >&2
    exit
}
detnam=$(dmkeypar "$dtf1" detnam ec+)

case "$detnam" in
    hrc-i) subdet=i ;;
    hrc-s) subdet=s ;;
    *) \echo "This script only handles HRC data." >&2
       exit 1
esac

\mkdir -p "$outdir/$subdet"
\rm -rf "$outdir/$subdet/$obsid"
\mv "$outdir/incomplete/$obsid" "$outdir/$subdet"

indir="$outdir/$subdet/$obsid"
outdir="$outdir/$subdet/$obsid/analysis"
\mkdir -p "$outdir"

evt1=$(\ls -1 "$indir/secondary/"hrcf${obsid}*"_evt1.fits"* 2>/dev/null)
[ -z "$evt1" ] && {
  \echo "FIXME: no EVT1 found in '$indir/secondary', exiting." >&2
  exit
}

#
# Some OBIs have been split, thus far they are ObsIDs
# 01411 00279 00108 02547 03764
#
IDS=None
[ $(wc -w <<< "$evt1") -gt 1 ] && {
    IDS=$(for f in $evt1; do echo $f | perl -nle '/(_\d\d\d)/ and print $1'; done)
}

nID=0
for ID in $IDS
do
    nID=$(( nID+1 ))
    [ "$ID" = None ] && ID=

#
# Boresight correction to the aspect solution.
#
dtf1=$(get_dtf1 "$indir")
asol1_stack=$(asol_stack "$indir")
[ -z "$asol1_stack" ] && {
  \echo "FIXME: no PCAD found in '$indir/primary', exiting." >&2
  exit
}

asol1="$outdir/hrcf${obsid}${ID}_asol1.fits"
tstart=$(dmkeypar "$dtf1" tstart ec+)
tstop=$(dmkeypar "$dtf1" tstop ec+)
punlearn dmmerge
dmmerge "$asol1_stack[time=${tstart}:${tstop}]" "$asol1" cl+
asp_offaxis_corr "$asol1" hrc
dmhedit "$asol1" file="" op=add key=CONTENT value=ASPSOLOBI

#
# patch_hrc_ssc
#
flt1=$(get_flt1 "$indir")
dmlist "$flt1" blocks | \grep -qi gti || {
  \echo "FIXME: no GTI found in '$flt1', exiting." 1>&2
  exit
}
true && {
    mtl1=$(get_mtl1 "$indir")
    evt1_old=$(get_evt1 "$indir")
    evt1_ssc="$outdir/hrcf${obsid}${ID}_evt1_ssc.fits"
    flt1_ssc=${evt1_ssc/evt1/std_flt1}
    dtf1_ssc=${evt1_ssc/evt1/dtf1}
    punlearn patch_hrc_ssc
    patch_hrc_ssc "$dtf1" "$mtl1" "$evt1_old" "$evt1_ssc" "$flt1_ssc" "$dtf1_ssc" 4000 cl+ 2>&1 | \tee $outdir/patch_hrc_ssc${ID}.log
    \grep -qi '^ssc detected' $outdir/patch_hrc_ssc${ID}.log && {
        evt1_old=$evt1_ssc
        flt1=$flt1_ssc
	dtf1=${dtf1_ssc/dtf1_ssc/dtf1}
	mv "$dtf1_ssc" "$dtf1"
    }
}

#
# if no SSC was detected, we either copy or unzip the archive evt1, dtf1
# to cwd
#
[ ! -f $outdir/patch_hrc_ssc${ID}.log ] || \grep -q '^SSC not detected' $outdir/patch_hrc_ssc${ID}.log && {
    evt1_old=$(get_evt1 "$indir")
    evt1_old_tmp="$outdir/"$(basename "$evt1_old" | \sed s/.gz$//).tmp
    [[ "$evt1_old" =~ .gz$ ]] && {
	gzip -dc "$evt1_old" > "$evt1_old_tmp"
    } || {
	\cp "$evt1_old" "$evt1_old_tmp"
    }
    evt1_old="$evt1_old_tmp"

    dtf1=${asol1/asol1/dtf1}
    dtf1_old=$(get_dtf1 "$indir")
    [[ "$dtf1_old" =~ .gz$ ]] && {
	gzip -dc "$dtf1_old" > "$dtf1"
    } || {
	\cp "$dtf1_old" "$dtf1"
    }
}

#ngti=$(flt1_good "$flt1")
#[ "$ngti" -gt 0 ] || {
  #\echo "FIXME: NO GTI FOUND IN '$flt1', exiting." 1>&2
  #exit
#}

#
# Ensure RANGELEV and WIDTHRES are correct
#
read rangelev widthres <<<$(rangelev_widthres_set "$evt1_old")

#
# Generate an observation parameter file containing the aspect
# solution boresight correction information.
#
obs_par=${asol1/asol1.fits/obs.par}
python "$SCRIPTDIR"/make_par "$evt1_old" "$asol1" "$obs_par" || {
  \echo "FIXME: $SCRIPTDIR/make_par $evt1_old $asol1 $obs_par failed, exiting." 1>&2
  exit
}
\echo range_switch_level,i,h,$rangelev',,,""' >> "$obs_par"
\echo width_threshold,i,h,$widthres',,,""' >> "$obs_par"

#
# Create a new badpix file.
#
bpix1=${asol1/asol/bpix}
punlearn hrc_build_badpix
hrc_build_badpix CALDB "$bpix1" "$obs_par" degapfile=CALDB cl+

punlearn geom
pset geom instruments="$SCRIPTDIR"/../data/new_geom.fits

#
# special cases of t_gmap
# 14238:             hrcsD2012-03-29t_gmapN0004.fits
# 14324,14396,14397: hrcsD1999-07-22t_gmapN0004.fits
#
gainfile=
[[ $obsid =~ 14238|14324|14396|14397 ]] && {
    gainfile="gainfile=$(match_caldb_file "$evt1_old" t_gmap)"
}

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
    $gainfile \
    cl+
r4_header_update "$evt1"

#
# create a new evt1 file with unrolled sky coordinates.
#
evt1_deroll=${evt1/evt1/deroll_evt1}
asol1_deroll=${asol1/asol/deroll_asol}
#
# deroll_asol returns an error code when {ra,dec,roll}_nom
# keywords are absent from the asol1 file. This should not be fatal
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

dmhedit "$evt1_old" filelist=none operation=add key=RA_NOM value=0.0
dmhedit "$evt1_old" filelist=none operation=add key=DEC_NOM value=0.0
dmhedit "$evt1_old" filelist=none operation=add key=ROLL_NOM value=0.0

obs_par_deroll=${obs_par/obs/deroll_obs}
python "$SCRIPTDIR"/make_par "$evt1_old" "$asol1_deroll" "$obs_par_deroll" || {
  \echo "FIXME: $SCRIPTDIR/make_par $evt1_old $asol1_deroll $obs_par_deroll failed, exiting." 1>&2
  exit
}
\echo range_switch_level,i,h,$rangelev',,,""' >> "$obs_par_deroll"
\echo width_threshold,i,h,$widthres',,,""' >> "$obs_par_deroll"

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
    $gainfile \
    cl+
r4_header_update "$evt1_deroll"

punlearn geom

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
[[ $detnam =~ hrc-s ]] && {
    filter='xxxxxx00xxxx0xxx0000x000x00000xx'
    order_list='-1,1,-2,2,-3,3'
} || {
    filter='xxxxxx00xxxx0xxx00000000x0000000'
    order_list='-1,1'
}

# generate TAILGATE column, paste to evt1
evt1_tailgate=${evt1/evt1/evt1_tailgate}
. /home/rpete/python3_venv/bin/activate
python3 "$SCRIPTDIR"/tailgate_flag.py "${evt1}" "${evt1_tailgate}"
deactivate
punlearn dmpaste
dmpaste "${evt1}" "${evt1_tailgate}" "${evt1}.tmp" cl+
\mv "${evt1}.tmp" "${evt1}"

flt_evt1=${evt1/evt1/flt_evt1}
dmcopy "${evt1}[status=$filter]" "$flt_evt1" cl+
flt_evt1_deroll=${evt1/evt1/flt_evt1_deroll}
dmcopy "${evt1_deroll}[status=$filter]" "$flt_evt1_deroll" cl+

#
# GTI filter
#
evt2=${evt1/evt1/evt2}
dmcopy "$flt_evt1[events][@${flt1}]" "$evt2" cl+
evt2_deroll=${evt1/evt1/deroll_evt2}
dmcopy "$flt_evt1_deroll[events][@${flt1}]" "$evt2_deroll" cl+

#
# correct LIVETIME, EXPOSURE, DTCOR
#
true && {
    dtfstats=${evt1/evt1/dtfstats}
    hrc_dtf_corr "$dtf1" "$dtfstats" "$flt1" "$evt2" || {
	echo "FIXME: hrc_dtf_corr failed, exiting." 1>&2
	exit
    }
}

#
# create barycentric-corrected file
#
eph1=$(\ls -1 "$indir"/primary/orbitf*_eph1.fits* 2>/dev/null | head -$nID | tail -1) || :
ra_targ=$(dmkeypar "$evt2" ra_targ ec+)
dec_targ=$(dmkeypar "$evt2" dec_targ ec+)
[ -z "$ra_targ" -o -z "$dec_targ" ] && {
    echo "FIXME: did not find (RA|DEC)_TARG in '$evt2'" >&2
    exit
}

evt2_bary=${evt2/evt2/evt2_bary}
evt2_deroll_bary_tailgate=${evt2/evt2/evt2_deroll_bary_tailgate}

dmcopy "${evt2_deroll}[col x,y]" "${evt2_deroll_bary_tailgate}" cl+

[ -n "$eph1" ] && {
    punlearn axbary
    axbary "$evt2" "$eph1" "$evt2_bary" $ra_targ $dec_targ cl+
    dmpaste "${evt2_deroll_bary_tailgate}" "${evt2_bary}[col time]" "${evt2_deroll_bary_tailgate}.tmp" cl+
    \mv "${evt2_deroll_bary_tailgate}.tmp" "${evt2_deroll_bary_tailgate}"
} || {
    echo "FIXME: did not find orbitf eph1 file in '$indir/primary'" >&2
}

# paste TAILGATE column to deroll_bary_tailgate
dmpaste "${evt2_deroll_bary_tailgate}" "${evt2}[col tailgate]" "${evt2_deroll_bary_tailgate}.tmp" cl+
\mv "${evt2_deroll_bary_tailgate}.tmp" "${evt2_deroll_bary_tailgate}"

grating=$(pquery "$obs_par" grating)

[[ "$grating" =~ [lh]etg ]] && {
    #
    # get source coordinates...
    #
    punlearn dmcoords
    dmcoords \
	infile="$evt2" \
	asolfile="$asol1" \
	option=cel \
	celfmt=deg \
	ra="$ra_targ" \
	dec="$dec_targ" \
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
    nsources=$(dmlist "$src2a" header,raw | grep -i naxis2 | perl -anle 'print $F[5]')

    false && {
	[ $nsources -gt 0 ] || {
	    punlearn celldetect
	    celldetect \
		infile="$evt2" \
		outfile="$src2a" \
		fixedcell=6 \
		maxlog=4096 \
		cl+
	    nsources=$(dmlist "$src2a" header,raw | grep -i naxis2 | perl -anle 'print $F[5]')
	}
    }

    [ $nsources -gt 0 ] || {
	\echo "FIXME: no sources detected in '$evt2'" >&2
	rm -f "$outdir"/_*.fits
	cleanup_files
	exit
    }

    [ $nsources -gt 1 ] && \echo "FIXME: nsources=$nsources" >&2

    L2a=${evt1/evt1/evt2_L1a}
    punlearn tg_create_mask
    tg_create_mask \
	infile="$evt2" \
	outfile="$L2a" \
	input_pos_tab="$src2a" \
	grating_obs=header_value \
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
    # (tg_mlam, pi) filter
    #
    [[ $detnam =~ hrc-s ]] && false && {
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

    \mv "$evt2a" "$evt2"

}

true && cleanup_files

done

[[ $obsid =~ 28377|28427 ]] && {
    "$SCRIPTDIR"/treat_HV_change.sh "$archivedir" $obsid
}

if [ $nID -gt 1 ]
then
    [ $nID -gt 2 ] && {
	\echo "FIXME: cannot handle links for $nID evt1 files" >&2
	exit
    }

    read ID1 ID2 <<<$(perl -le 'chomp(@lines=<>); print join " ",@lines' <<<"$IDS")

    for ln_targ in "$outdir"/*${obsid}$ID1*
    do
	ln_name="$outdir/"$(sed s/$ID1// <<<$(basename "$ln_targ"))
	ln -fs $(basename "$ln_targ") "$ln_name"
    done

    [ -d "$outdir/tg" ] && {
	for ln_targ in "$outdir"/tg/*${obsid}$ID1*
	do
	    ln_name="$outdir/tg/"$(sed s/$ID1// <<<$(basename "$ln_targ"))
	    ln -fs $(basename "$ln_targ") "$ln_name"
	done
    }

    obsid2=$(( $(sed s/^0*// <<<$obsid) + 90000 ))
    newoutdir=$(dirname $(dirname "$outdir"))/$obsid2/analysis
    rm -rf $newoutdir
    mkdir -p "$newoutdir"
    for ln_targ in "$outdir"/*${obsid}$ID2*
    do
	ln_name="$newoutdir"/$(sed s/${obsid}${ID2}/${obsid2}/ <<<$(basename "$ln_targ"))
	ln -fs ../../$obsid/analysis/$(basename "$ln_targ") "$ln_name"
    done

    [ -d "$outdir/tg" ] && {
	mkdir -p "$newoutdir/tg"
	for ln_targ in "$outdir"/tg/*${obsid}$ID2*
	do
	    ln_name="$newoutdir/tg/"$(sed s/${obsid}${ID2}/${obsid2}/ <<<$(basename "$ln_targ"))
	    ln -fs ../../../$obsid/analysis/tg/$(basename "$ln_targ") "$ln_name"
	done
    }
fi
