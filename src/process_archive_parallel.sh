#! /bin/bash

[ $# -eq 0 ] || {
  \echo "Usage: $0" 1>&2
  exit 1
}

n=13

set -e
set -o pipefail

. ~/python3_venv/bin/activate
tmpfile=$(mktemp)
#python3 /data/legs/rpete/flight/hrc_archive/src/obsids.py > "$tmpfile"
cp -a /data/legs/rpete/flight/hrc_archive/obsids_todo "$tmpfile"
outdir=/data/loss/rpete/hrc

cp -a /data/legs/rpete/flight/hrc_archive/obsids_tmp "$tmpfile"
outdir=/data/loss/rpete/hrc2

cp -a /data/legs/rpete/flight/hrc_archive/obsids_hz43 "$tmpfile"
outdir=/data/loss/rpete/hz43_patch_hrc_ssc_100000

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
