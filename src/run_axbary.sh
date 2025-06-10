#! /bin/bash

set -eo pipefail

[ $# -eq 1 ] || {
    \echo "Usage: $0 dir" 1>&2
    exit 1
}

dir="$1"

evt2=$(ls "$dir"/analysis/hrcf[0-9][0-9][0-9][0-9][0-9]_evt2.fits)
nevt2=$(echo "$evt2" | wc -w)
[ $nevt2 -eq 1 ] || {
    echo "found $nevt2 evt2 files in '$dir/analysis'" 1>&2
    exit
}

eph1=$(ls "$dir"/primary/orbitf*_eph1.fits*)
neph1=$(echo "$eph1" | wc -w)
[ $neph1 -eq 1 ] || {
    echo "found $neph1 eph1 files in '$dir/primary'" 1>&2
    exit
}

SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

. ~/.bash_aliases
shopt -s expand_aliases nocasematch

#
# CIAO init doesn't work with bash nounset mode
#
reset_u=0
[[ $- =~ u ]] && {
    set +u
    reset_u=1
}
ciao
[ $reset_u -eq 1 ] && set -u

. $SCRIPTDIR/tmppdir.sh


ra_targ=$(dmkeypar "$evt2" ra_targ ec+)
dec_targ=$(dmkeypar "$evt2" dec_targ ec+)
[ -z "$ra_targ" -o -z "$dec_targ" ] && {
    echo "FIXME: did not find (RA|DEC)_TARG in '$evt2'" 1>&2
    exit
}

evt2_bary=${evt2/evt2/evt2_bary}
punlearn axbary
axbary "$evt2" "$eph1" "$evt2_bary" $ra_targ $dec_targ
