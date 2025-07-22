#! /bin/bash

# process set i of n for either I or S detector

set -eo pipefail

[ $# -eq 4 ] || {
  \echo "Usage: obsid_file outdir i n" 1>&2
  exit 1
}

ofile="$1"
outdir="$2"
i=$3
n=$4

[ $i -le $n ] || {
  \echo "i must be less than or equal to n" 1>&2
  exit 1
}

script=/data/legs/rpete/flight/hrc_archive/src/process_archive_obsids.sh

. /data/legs/rpete/flight/analysis_functions/util.bash

obsids=$(cat "$ofile")
obsids=''

obsids=$(i_of_n $i $n $obsids)
bash -x "$script" "$outdir" $obsids
