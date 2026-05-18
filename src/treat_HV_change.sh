#! /bin/bash

umask 022

set -eo pipefail

[ $# -ge 2 ] || {
    \echo "Usage: $0 archivdir 28377|28427" >&2
    exit 1
}
archivedir="$1"
shift
obsids_="$@"

SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

. $SCRIPTDIR/hrc_archive_repro_functions.sh

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

. $SCRIPTDIR/tmppdir.sh

declare -A time obsids tg_order_list outdirs

tg_order_list=(
    ['HRC-S']=-1,1,-2,2,-3,3
    ['HRC-I']=-1,1
)

time=(
    [old_28377]=833996762.38510537:834001803.33543313
    [new_28377]=834001975.53544438:834006772.53575635
    [old_28427]=834518958.91906822:834524996.16946101
    [new_28427]=834525190.91947365:834528969.06972170
)

for obsid in $obsids_
do
    [[ "$obsid" =~ 28377|28427 ]] || {
	echo "ObsID=$obsid is unhandled" >&2
	exit 1
    }
    outdir=$(echo "$archivedir"/[is]/$obsid/analysis)
    [ -d "$outdir" ] || {
	echo "Does not exist: '$outdir'" >&2
	exit 1
    }

    [ -d "$outdir"/../analysis.orig ] || {
	mkdir "$outdir"/../analysis.orig
	mv "$outdir"/* "$outdir"/../analysis.orig
    }
    
    obsids=(
        [old]=$obsid
        [new]=${obsid/2/7}
    )

    newdir="$(dirname $(dirname "$outdir"))"/${obsids[new]}/analysis
    rm -rf "$(dirname "$newdir")"
    mkdir -p "$newdir"

    evt2_orig="$outdir"/../analysis.orig/hrcf${obsids[old]}_evt2.fits

    detnam=$(dmkeypar "$evt2_orig" detnam ec+)

    outdirs=(
	[old]="$outdir"
	[new]="$newdir"
    )

    for hv in old new
    do
        evt2="${outdirs[$hv]}"/hrcf${obsids[$hv]}_evt2.fits
        pha2="${outdirs[$hv]}"/hrcf${obsids[$hv]}_pha2.fits

	dmcopy "$evt2_orig"'[time='${time[${hv}_${obsid}]}']' "$evt2" cl+
	dmappend "$evt2_orig"'[region][subspace -time]' "$evt2"

	tgextract infile="$evt2" outfile="$pha2" \
                  tg_srcid_list=all \
                  tg_part_list=header_value \
                  inregion_file=CALDB \
                  tg_order_list=${tg_order_list[$detnam]} \
                  cl+ \
                  outfile_type=pha_typeII \
                  ancrfile=none \
                  respfile=none

	[ "$hv" = new ] && {
	    for f in $evt2 $pha2
            do
                dmhedit "$f" none add obs_id ${obsids[$hv]}
            done
        }

	# requires these to be set:
	# $obsid
	# $evt2a
	# $pha2
	# $asol1
	# $dtf1
	# $bpix1
	# $outdir = analysis

	obsid=${obsids[$hv]}
	evt2a="$evt2"
	asol1="${outdirs[old]}"/../analysis.orig/hrcf${obsids[old]}_asol1.fits
	dtf1="${outdirs[old]}"/../analysis.orig/hrcf${obsids[old]}_dtf1.fits
	bpix1="${outdirs[old]}"/../analysis.orig/hrcf${obsids[old]}_bpix1.fits
	outdir="${outdirs[$hv]}"
	echo obsid=$obsid
	echo evt2a=$evt2a
	echo asol1=$asol1
	echo dtf1=$dtf1
	echo bpix1=$bpix1
	echo outdir=$outdir
	make_response
    done

done
