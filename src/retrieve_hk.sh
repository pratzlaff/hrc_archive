#! /bin/bash

SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

. ~/python3_venv/bin/activate
obsids=$(python3 "$SCRIPTDIR"/obsids.py --no-ignore_existing)
deactivate

for o in $obsids
do
  [ -d /data/hrc/[is]/$o/hk ] || {
    echo "no hk dir for $o" 1>&2
    continue
  }

  [ -d /data/hrc/i/$o/hk ] && {
    outdir=/data/hrc/i/$o/hk
  } || {
    outdir=/data/hrc/s/$o/hk
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
