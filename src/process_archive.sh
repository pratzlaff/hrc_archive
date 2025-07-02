#! /bin/bash

# process set i of n for either I or S detector

set -eo pipefail

[ $# -eq 4 ] || {
  \echo "Usage: obsid_file outdir i n" 1>&2
  exit 1
}

ofile="$1"
outdir="$2"
i=$3
n=$4

[ $i -le $n ] || {
  \echo "i must be less than or equal to n" 1>&2
  exit 1
}

script=/data/legs/rpete/flight/hrc_archive/src/hrc_archive_repro.sh
logdir="$outdir/incomplete"
mkdir -p "$logdir"

. /data/legs/rpete/flight/analysis_functions/util.bash

obsids=$(cat "$ofile")

obsids=$(i_of_n $i $n $obsids)
nobsids=$(\echo $obsids | wc -w)
j=0
echo $obsids
for obsid in $obsids
do
  (( ++j ))
  obsid=$(printf %05d $(sed s/^0*// <<<$obsid))
  \echo "********** Processing ObsID $obsid: $j of $nobsids **********" 1>&2
  bash -x $script $obsid $outdir 2>&1 | \tee "$logdir/hrc_archive_repro.log.$obsid"

  # in cases where there was not data downloaded, there won't be [is]/$obsid directory
  for subdet in i s
  do
    testdir="$outdir/$subdet/$obsid"
    [ -d "$testdir" ] && mv "$logdir/hrc_archive_repro.log.$obsid" "$testdir/hrc_archive_repro.log"
  done
done
