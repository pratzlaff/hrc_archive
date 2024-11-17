#! /bin/bash

# process set i of n for either I or S detector

set -e
set -o pipefail

[ $# -eq 3 ] || {
  \echo "Usage: i|s i n" 1>&2
  exit 1
}

det="$1"; det=${det,,}
i="$2"
n="$3"

case $det in
  i|s) ;;
    *) \echo "detector must be i or s" 1>&2
       exit 1;
       ;;
esac

[ $i -le $n ] || {
  \echo "i must be than or equal to n" 1>&2
  exit 1
}

script=/data/legs/rpete/flight/hrc_archive/src/hrc_archive_repro.sh
indir=/data/hrc/$det
outdir=/data/loss/rpete/hrc/$det

. /data/legs/rpete/flight/analysis_functions/util.bash
obsids=$(\echo $indir/[0-9][0-9][0-9][0-9][0-9] | perl -pnle "s|$indir/||g")

obsids=$(i_of_n $i $n $obsids)
nobsids=$(\echo $obsids | wc -w)
j=0
for obsid in $obsids
do
  (( ++j ))
  \echo "********** Processing ObsID $obsid: $j of $nobsids **********" 1>&2
  mkdir -p $outdir/$obsid/analysis
  #echo "$script $indir/$obsid $outdir/$obsid/analysis 2>&1 | \tee $outdir/$obsid/analysis/hrc_archive_repro.log"
  bash -x $script $indir/$obsid $outdir/$obsid/analysis 2>&1 | \tee $outdir/$obsid/analysis/hrc_archive_repro.log
done
