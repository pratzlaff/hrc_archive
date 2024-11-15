#! /bin/bash

set -e
set -o pipefail

script=/data/legs/rpete/flight/hrc_archive/src/hrc_archive_repro.sh
indir=/data/hrc/i
outdir=/data/loss/rpete/hrc/i

n=16
. /data/legs/rpete/flight/analysis_functions/util.bash
obsids=$(echo $indir/[0-9][0-9][0-9][0-9][0-9] | perl -pnle "s|$indir/||g")
sname=archive
screen -dmS $sname
eval "
for i in {1..$n}"'
do
  oo=$(i_of_n $i '"$n"' $obsids)
  screen -S $sname -X screen time bash -c "for o in $oo; do echo $script $indir/$o $outdir/$o; exec bash"
done'
screen -S $sname -p0 -X kill
screen -rS $sname
