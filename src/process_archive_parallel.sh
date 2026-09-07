#! /bin/bash

set -eo pipefail

SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

[ $# -eq 0 ] || {
  \echo "Usage: $0" 1>&2
  exit 1
}

n=4

script="$SCRIPTDIR"/process_archive_obsids.sh
parallel="$SCRIPTDIR"/parallel

false && {
  . /home/rpete/python3_venv/bin/activate
  obsids=$(python3 "$SCRIPTDIR"/obsids.py --no-ignore_existing --start 1999-07-01)
  deactivate
  outdir=/data/loss/rpete/hrc
}

false && {
  obsids=$(cat "$SCRIPTDIR"/../data/obsids_hz43)
  outdir=/data/loss/rpete/hz43_patch_hrc_ssc
}

true && {
  obsids=$(\grep -h '^[0-9]' "$SCRIPTDIR"/../data/obsids_tgdetect2_misses_[is])
  outdir=/data/loss/rpete/hrc
}

mkdir -p "$outdir"

time "$parallel" -j $n "$script" "$outdir" ::: $obsids
