#! /bin/bash

set -e
set -o pipefail

outdir=/data/loss/rpete/hrc

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

SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

obsids=$(python3 "$SCRIPTDIR"/obsids.py)

for obsid in $obsids
do
    subdet=
    for s in i s
    do
	[ -d "$outdir/$s/$obsid" ] && {
	    subdet=$s
	    continue
	}
    done

    [ -z "$subdet" ] && {
	echo "FIXME: '$outdir/[is]/$obsid' not found." 1>&2
	continue
    }

    cd "$outdir/$subdet"

    obsid_dl=$(sed s/^0*// <<< $obsid)
    [ "$obsid_dl" != "$obsid" ] && ln -fs "./$obsid" "$outdir/$subdet/${obsid_dl}"
    download_chandra_obsid "${obsid_dl}" vv,vvref
    [ "$obsid_dl" != "$obsid" ] && rm -f "$outdir/$subdet/${obsid_dl}"
    cd -
    
done

