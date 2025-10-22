#! /bin/bash

set -eo pipefail

[ $# -eq 0 ] || {
  \echo "Usage: $0" 1>&2
  exit 1
}

n=4

outdir=/data/loss/rpete/hrc
script=/data/legs/rpete/flight/hrc_archive/src/process_archive_obsids.sh
parallel=/data/legs/rpete/flight/hrc_archive/src/parallel

. /home/rpete/python3_venv/bin/activate
obsids=$(python3 /data/legs/rpete/flight/hrc_archive/src/obsids.py)
deactivate

time "$parallel" --dry-run -j $n bash "$script" "$outdir" ::: $obsids
