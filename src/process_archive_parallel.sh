#! /bin/bash

set -eo pipefail

[ $# -eq 0 ] || {
  \echo "Usage: $0" 1>&2
  exit 1
}

# number of simultaneou screen sessions
n=3

tmpfile=$(mktemp)
outdir=/data/loss/rpete/hrc
script=/data/legs/rpete/flight/hrc_archive/src/process_archive_i_of_n.sh

. /home/rpete/python3_venv/bin/activate
python3 /data/legs/rpete/flight/hrc_archive/src/obsids.py > "$tmpfile"
deactivate

sname=archive
screen -dmS $sname
for i in $(seq $n)
do
  screen -S $sname -X screen bash -c "time $script $tmpfile $outdir $i $n; exec bash;"
done
screen -S $sname -p0 -X kill
screen -rS $sname 

rm -f  "$tmpfile"
