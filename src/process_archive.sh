#! /bin/bash

# process set i of n for either I or S detector

set -e
set -o pipefail

[ $# -eq 2 ] || {
  \echo "Usage: i n" 1>&2
  exit 1
}

i=$1
n=$2

[ $i -le $n ] || {
  \echo "i must be than or equal to n" 1>&2
  exit 1
}

script=/data/legs/rpete/flight/hrc_archive/src/hrc_archive_repro.sh
outdir=/data/loss/rpete/hrc2
logdir="$outdir/logs"
mkdir -p "$logdir"

. /data/legs/rpete/flight/analysis_functions/util.bash
obsids=$(python3 /data/legs/rpete/flight/hrc_archive/src/obsids.py)

obsids=$(i_of_n $i $n $obsids)
nobsids=$(\echo $obsids | wc -w)
j=0
echo $obsids
for obsid in $obsids
do
  (( ++j ))
  \echo "********** Processing ObsID $obsid: $j of $nobsids **********" 1>&2
  #echo "$script $indir/$obsid $outdir/$obsid/analysis 2>&1 | \tee $outdir/$obsid/analysis/hrc_archive_repro.log"
  bash -x $script $obsid $outdir 2>&1 | \tee "$logdir/hrc_archive_repro.log.$obsid"

  # in cases where there was not data downloaded, there won't be [is]/$obsida directory
  for subdet in i s
  do
    testdir="$outdir/$subdet/$obsid"
    [ -d "$testdir" ] && mv "$logdir/hrc_archive_repro.log.$obsid" "$testdir/hrc_archive_repro.log"
  done
done
