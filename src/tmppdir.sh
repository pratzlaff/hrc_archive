#! /bin/bash

# taken from https://stackoverflow.com/questions/4632028/how-to-create-a-temporary-directory

# option to designate tmp path has been removed since it was interfering
# with other scripts handling of command-line options

#dir_='/tmp'
#[ -z "$1" ] || dir_="$1"

# the temp directory used, within $DIR omit the -p parameter to
# create a temporal directory in the default location
#pdir=`mktemp -d -p "$dir_"`

pdir=`mktemp -d`

# check if tmp dir was created
if [[ ! "$pdir" || ! -d "$pdir" ]]; then
    \echo "Could not create temp dir"
    exit 1
fi

# deletes the temp directory
function cleanup {      
    \rm -rf "$pdir"
    \echo "Deleted temp working directory $pdir" 1>&2
}

# register the cleanup function to be called on the EXIT signal
trap 'exit 1' HUP INT PIPE QUIT TERM
trap cleanup EXIT

#PFILES="$pdir;"$(echo "$PFILES" | perl -F';' -le 'print $F[1]')
PFILES="$pdir;${PFILES#*;}"
