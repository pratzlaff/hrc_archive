#! /bin/bash

. ~/python3_venv/bin/activate
obsids=$(python3 /data/legs/rpete/flight/hrc_archive/src/obsids.py --no-ignore_existing)
deactivate

for o in $obsids
do
  [ -d /data/loss/rpete/hrc/[is]/$o/hk ] || {
    echo "no hk dir for $o" 1>&2
    continue
  }

  [ -d /data/loss/rpete/hrc/i/$o/hk ] && {
    outdir=/data/loss/rpete/hrc/i/$o/hk
  } || {
    outdir=/data/loss/rpete/hrc/s/$o/hk
  }

  echo $outdir
  cd "$outdir"
   /proj/axaf/simul/bin/arc5gl -stdin <<EOP 1>/dev/null
dataset=flight
obsid=$o
retrieve hrc0
EOP
  cd -

done
