#! /bin/bash

set -eo pipefail

[ $# -eq 0 ] || {
  \echo "Usage: $0" 1>&2
  exit 1
}

n=4

script=/data/legs/rpete/flight/hrc_archive/src/process_archive_obsids.sh
parallel=/data/legs/rpete/flight/hrc_archive/src/parallel

false && {
  . /home/rpete/python3_venv/bin/activate
  obsids=$(python3 /data/legs/rpete/flight/hrc_archive/src/obsids.py --no-ignore_existing --start 1999-07-01)
  deactivate
  outdir=/data/hrc
}

false && {
  obsids=$(cat /data/legs/rpete/flight/hrc_archive/obsids_hz43)
  outdir=/data/loss/rpete/hz43_patch_hrc_ssc
}

mkdir -p "$outdir"

time "$parallel" -j $n "$script" "$outdir" ::: $obsids
