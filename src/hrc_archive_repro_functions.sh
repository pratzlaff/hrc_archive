#! /bin/bash

download_data()
{
    [ $# -eq 2 ] || {
	\echo "Usage: $0 obsid outdir" 1>&2
	exit 1
    }
    local obsid="$1"
    local outdir="$2"

    \mkdir -p "$outdir"/{primary,secondary,hk}
    \cd "$outdir"

    /proj/axaf/simul/bin/arc5gl -stdin <<EOP #1>/dev/null
dataset=flight
operation=retrieve
obsid=$obsid
detector=ephem
subdetector=orbit
level=1
go
detector=hrc
subdetector=
level=0.5
filetype=hrcss0_5
go
level=0
filetype=hrcss
go
level=0
filetype=evt0
go
filetype=hrc4eng
subdetector=eng
go
retrieve asp1[pcadf*asol1.fits*]
retrieve hrc1
EOP

    # if arc5gl gives both obsid-named files, delete those that are
    # timestamp-named (this seems to be what download_chandra_obsid does)
    ls pcadf*asol1.fits* | grep -q pcadf${obsid}_ && rm -f $(ls pcadf*asol1.fits* |  grep -v pcadf${obsid}_)

    rm -f *aoff* *soff*

    \mv *_{eph,dtf,fov,asol}1.fits* primary
    \mv *_{bpix,evt,msk,mtl,std_flt,std_dtfstat}1.fits* secondary
    \mv *_{4_eng,evt,ss}0.fits* *_ss0a.fits* hk

    \cd -
    ls $outdir/secondary/*evt1.fits* 1>/dev/null 2>&1
}

flt1_good()
{
    local flt1="$1"
    dmstat "$flt1"'[gti][col start]' 1>/dev/null 2>&1
    pget dmstat out_good
}

asol_stack()
{
    #\ls "$1"/primary/pcadf*asol1.fits* | perl -le 'chomp(@f=<>); print join(",", @f)'
    \ls -1 "$1"/primary/pcadf*asol1.fits* 2>/dev/null | \tr '\n' , | \sed 's/,$/\n/' || \echo -n ''
}

osol_stack()
{
    #\ls "$1"/secondary/aspect/pcadf*osol1.fits* | perl -le 'chomp(@f=<>); print join(",", @f)'
    \ls -1 "$1"/secondary/aspect/pcadf*osol1.fits* 2>/dev/null | \tr '\n' , | \sed 's/,$/\n/' || \echo -n ''
}

get_type()
{
    local dir="$1"
    local type="$2"
    \ls "$dir/"*"${type}.fits"* 2>/dev/null | \tail -1 || \echo -n ''
}

get_evt1()
{
    get_type "$1/secondary" evt1
}

get_flt1()
{
    get_type "$1/secondary" flt1
}

get_mtl1()
{
    get_type "$1/secondary" mtl1
}

get_dtf1()
{
    get_type "$1/primary" dtf1
}

get_fov1()
{
    get_type "$1/primary" fov1
}

hrc_dtf_corr()
{
    local dtf1="$1"
    local dtfstats="$2"
    local flt1="$3"
    local evt="$4"

    punlearn hrc_dtfstats
    hrc_dtfstats \
	infile="$dtf1" \
	outfile="$dtfstats" \
	gtifile="$flt1[filter]" \
	cl+

    local dtcor=$(dmlist "$dtfstats[col dtcor]" data,raw | \tail -1 | \sed 's/ //g')
    local ontime=$(dmkeypar $evt ontime ec+)
    local livetime=$(\echo "$dtcor*$ontime" | bc -l)
    dmhedit "$evt" filelist="" op=add key=livetime value="$livetime" 
    dmhedit "$evt" filelist="" op=add key=exposure value="$livetime"
    dmhedit "$evt" filelist="" op=add key=dtcor value="$dtcor"
}

#
# I've tried setting these in the obsfile handed to hpe, but it
# doesn't stick, so set them in the input evt1 file instead.
#
rangelev_widthres_set()
{
    local evt="$1"
    date_obs=$(dmkeypar "$evt" date-obs ec+)
    detnam=$(dmkeypar "$evt" detnam ec+)
    local rangelev=90
    local widthres=3
    [ "$date_obs" \> 1999-12-06 ] && {
	case $detnam in
	    hrc-i*) rangelev=115 ;;
	    hrc-s*) rangelev=125 ;;
	    *) \echo "Unrecognized DETNAM='$detnam'" 1>&2; exit 1 ;;
	esac
    }
    [ "$date_obs" \> 2000-10-05 ] && widthres=2
    dmhedit infile="$evt" filelist=none operation=add key=rangelev value=$rangelev
    dmhedit infile="$evt" filelist=none operation=add key=widthres value=$widthres
    \echo $rangelev $widthres
}

make_response()
{
    local evt2="$evt2a"
    local rmfdir=../../../../rmfs

    case "$detnam" in
        hrc-i*) detsubsys=HRC-I
                detstr=hrci
                ;;
        hrc-s*) detsubsys=HRC-S2
                detstr=hrcs
                ;;
    esac

    local tg_m
    local tg_part
    local grating_arm
    local rmffile

    local row=0
    dmlist "$pha2"'[cols tg_m, tg_part]' data,raw | \grep -v '^#' | while read line
    do
	(( row++ ))
        read tg_m tg_part <<<$(echo "$line")
	case "$tg_part" in
	    1) grating_arm=HEG ;;
	    2) grating_arm=MEG ;;
	    3) grating_arm=LEG ;;
	    *) \echo "make_rmfs() - unrecognized TG_PART=$tg_part in $pha2" 1>&2
	       return 1 ;;
	esac

	[ $grating_arm = LEG ] || detsubsys=ACIS-S3

	# end up with m1,p1,m2,p2,m3,p3,etc
	local ostr=p$tg_m
	[ $tg_m -lt 0 ] && ostr=m$(( -$tg_m ))
	local rmfin="$rmfdir/${detstr}_${grating_arm,,}_${ostr}.rmf"
	local rmfout="$outdir/tg/hrcf${obsid}_${grating_arm,,}_${ostr}.rmf"
	mkdir -p "$outdir/tg"
	\ln -fs "$rmfin" "$rmfout"

	false && {
	punlearn mkgrmf
	mkgrmf \
            grating_arm="$grating_arm" \
            order="$tg_m" \
            outfile="$rmfout" \
            srcid=1 \
            detsubsys=$detsubsys \
            threshold=1e-06 \
            obsfile="$pha2"'[SPECTRUM]' \
            regionfile="$pha2" \
            wvgrid_arf=compute \
            wvgrid_chan=compute \
            clobber=yes
	}

	punlearn mkgarf
	punlearn fullgarf
	\mkdir -p "$outdir/fullgarf"
	$SCRIPTDIR/fullgarf \
            "$pha2" \
            "$row" \
            "$evt2" \
            "$asol1" \
            "grid($rmfout[cols ENERG_LO,ENERG_HI])" \
            "$dtf1" \
            "$bpix1" \
            "$outdir/fullgarf/${obsid}_" \
            maskfile=NONE \
            clobber=yes
	local arfout="$outdir/tg/hrcf${obsid}_${grating_arm,,}_${ostr}.arf"
	\mv "$outdir/fullgarf/${obsid}_${grating_arm}_${tg_m}_garf.fits" \
	   "$arfout"
    done
    \rm -rf "$outdir/fullgarf"

    local x y
    read x y <<<$( dmlist "$evt2"'[region][col sky]' data,raw | \head -2 | \tail -1 )

    local asphist="$outdir/${obsid}_asphist.fits"
    punlearn asphist
    asphist \
        "$asol1" \
        "$asphist" \
        "$evt2" \
        "$dtf1"

    local arf="$outdir/tg/hrcf${obsid}_0th.arf"
    local rmffile=$(\ls "$outdir/tg/hrcf${obsid}_"*"_p1.rmf" | \tail -1)
    local grating=$(dmkeypar "$pha2" grating ec+)
    punlearn mkarf
    mkarf \
        asphistfile="$asphist" \
        outfile="$arf" \
        sourcepixelx="$x" \
        sourcepixely="$y" \
        engrid='grid('"$rmffile"'[cols ENERG_LO,ENERG_HI])' \
        obsfile="$pha2"'[SPECTRUM]' \
        detsubsys="$detsubsys" \
        grating=$grating \
        maskfile=NONE \
        verbose=0 \
        clobber+
}


repro_asol1()
{
    local indir="$1"
    local outdir="$2"
    local asol1=$(asol_stack "$indir/primary")
    local asol1_repro="$outdir/pcad_repro_asol1.fits"
    local dtf1=$(get_dtf1 "$indir")
    local tstart=$(dmkeypar "$dtf1" tstart ec+)
    local tstop=$(dmkeypar "$dtf1" tstop ec+)

    punlearn dmmerge
    dmmerge "$asol1[time=${tstart}:${tstop}]" "$asol1_repro" cl+
    asol1="$asol1_repro"
    asp_offaxis_corr "$asol1" hrc
    dmhedit "$asol1" file="" op=add key=CONTENT value=ASPSOLOBI

    \echo "$asol1"
}

make_pcad_obs()
{
    local indir="$1"
    local outdir="$2"
    local asol1="$outdir/pcad_repro_asol1.fits"
    local evt1=$(get_evt1 "$indir")
    local pcad_obs="$outdir/pcad_obs.par"
    python "$scriptdir"/make_par "$evt1" "$asol1" "$pcad_obs"
    \echo "$pcad_obs"
}

gainfile_cases()
{
    local obsid="$1"

    local gainfile_hv1="${CALDB}"/data/chandra/hrc/t_gmap/hrcsD1999-07-22t_gmapN0004.fits
    local gainfile_hv2="${CALDB}"/data/chandra/hrc/t_gmap/hrcsD2012-03-29t_gmapN0004.fits

    local hv1_obsids=( 14324 14396 14397 ) # taken 2012-07-04
    local hv2_obsids=( 14238 )             # taken 2012-03-18

    local gainfile=''

    for o in ${hv1_obsids[@]}
    do
	[ $obsid -eq $o ] && gainfile="gainfile=${gainfile_hv1}"
    done

    for o in ${hv2_obsids[@]}
    do
	[ $obsid -eq $o ] && gainfile="gainfile=${gainfile_hv2}"
    done

    \echo "$gainfile"
}

run_hrc_process_events()
{
    local indir="$1"
    local outdir="$2"
    local evt1_in=$(get_type "$indir/secondary" evt1)
    local obs_par="$outdir/pcad_obs.par"
    local obsid=$(printf "%05d" $(pquery "$obs_par" obs_id))

    punlearn hrc_process_events
}

run_hrc_build_badpix()
{
    local outdir="$1"
    local obs_par="$outdir/pcad_obs.par"
    local obsid=$(printf "%05d" $(pquery "$obs_par" obs_id))
    local bpix1="$outdir/hrcf${obsid}_bpix1.fits"

    punlearn hrc_build_badpix
    hrc_build_badpix CALDB "$bpix1" "$obs_par" degapfile=CALDB cl+

    \echo $bpix1
}
