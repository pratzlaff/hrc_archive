#! /bin/bash

[ $# -eq 0 ] || {
  \echo "Usage: $0" 1>&2
  exit 1
}

n=1

set -e
set -o pipefail

. ~/python3_venv/bin/activate
tmpfile=$(mktemp)
python3 /data/legs/rpete/flight/hrc_archive/src/obsids.py > "$tmpfile"

script=/data/legs/rpete/flight/hrc_archive/src/process_archive.sh

sname=archive
screen -dmS $sname
for i in $(seq $n)
do
  screen -S $sname -X screen bash -c "time $script $tmpfile $i $n; exec bash;"
done
screen -S $sname -p0 -X kill
screen -rS $sname 

rm -f  "$tmpfile"
