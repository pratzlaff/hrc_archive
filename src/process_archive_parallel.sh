#! /bin/bash

det=i
n=16

set -e
set -o pipefail

script=/data/legs/rpete/flight/hrc_archive/process_archive.sh

sname=archive
screen -dmS $sname
for i in $(seq $n)
do
  screen -S $sname -X screen bash -c "time $script $det $i $n; exec bash;"
done
screen -S $sname -p0 -X kill
screen -rS $sname 
