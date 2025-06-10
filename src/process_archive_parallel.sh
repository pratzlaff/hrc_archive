#! /bin/bash

set -eo pipefail

[ $# -eq 0 ] || {
  \echo "Usage: $0" 1>&2
  exit 1
}


n=13
n=4

. ~/python3_venv/bin/activate
tmpfile=$(mktemp)
python3 /data/legs/rpete/flight/hrc_archive/src/obsids.py > "$tmpfile"
outdir=/data/loss/rpete/hrc

#cp -a /data/legs/rpete/flight/hrc_archive/obsids_hz43 "$tmpfile"
#outdir=/data/loss/rpete/hz43_patch_hrc_ssc

script=/data/legs/rpete/flight/hrc_archive/src/process_archive.sh

sname=archive
screen -dmS $sname
for i in $(seq $n)
do
  screen -S $sname -X screen bash -c "time $script $tmpfile $outdir $i $n; exec bash;"
done
screen -S $sname -p0 -X kill
screen -rS $sname 

rm -f  "$tmpfile"
