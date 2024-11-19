#! /bin/bash

[ $# -eq 0 ] || {
  \echo "Usage: $0" 1>&2
  exit 1
}

n=12

set -e
set -o pipefail

script=/data/legs/rpete/flight/hrc_archive/src/process_archive.sh

sname=archive
screen -dmS $sname
for i in $(seq $n)
do
  screen -S $sname -X screen bash -c "time $script $i $n; exec bash;"
done
screen -S $sname -p0 -X kill
screen -rS $sname 
