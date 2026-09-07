#! /bin/bash

set -eo pipefail

[ $# -eq 0 ] || {
  \echo "Usage: $0" 1>&2
  exit 1
}

SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

outdir=/data/hrc
script="$SCRIPTDIR"/process_archive_obsids.sh

. /home/rpete/python3_venv/bin/activate
obsids=$(python3 "$SCRIPTDIR"/obsids.py)
deactivate

time bash "$script" "$outdir" $obsids
