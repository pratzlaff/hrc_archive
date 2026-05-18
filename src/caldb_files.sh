#! /bin/bash

lsfparm_files() {
    local det="$1"
    local arm=${2,,}
    local dir="$3"
    local version="$4"

    case "$det" in
	hrc*|acis*) ;;
	*) echo "lsfparm_files() - unrecognized detector name='$det' " 1>&2
	   return 1
	   ;;
    esac

    case "$arm" in
	[lmh]eg) ;;
	*) echo "lsfparm_files() - unrecognized grating arm='$arm' " 1>&2
	   return 1
	   ;;
    esac
    
    case $# in
	2) dir="$CALDB/data/chandra/$det/lsfparm"; version='N[[:digit:]]{4}' ;;
	3) version='N[[:digit:]]{4}' ;;
	4) ;;
	*) echo 'Usage: lsfparm_files det arm [directory [version]]' 1>&2
	   return 1
	   ;;
    esac

    local posfile=$(\ls "$dir/${det}"*"${arm}1D"*lsfparm*.fits | \egrep "D[[:digit:]]{4}(-[[:digit:]]{2}){2}lsfparm${version}.fits" | tail -1)

    local negfile=$(\ls "$dir/${det}"*"${arm}-1D"*lsfparm*.fits | \egrep "D[[:digit:]]{4}(-[[:digit:]]{2}){2}lsfparm${version}.fits" | tail -1)
    echo "$negfile" "$posfile"
}

match_caldb_file() {

    [ "$#" -ge 2 ] || {
	echo "Usage: $0 obsfile type [dir] [version]\n" >&2
	exit 1
    }

    local obsfile="$1"
    local type="$2"
    local dir="$3"
    local version="$4"

    local detnam=$(dmkeypar "$obsfile" detnam echo+)
    local dateobs=$(dmkeypar "$obsfile" date-obs echo+)
    local obsid=$(dmkeypar "$obsfile" obs_id echo+)

    #
    # special cases for first HRC-S HV change test observations, I
    # believe they only affect the qe, qeu, and t_gmap files
    #
    local old_hv=( 14324 14396 14397 ) # taken 2012-07-04
    local new_hv=( 14238 ) # taken 2012-03-18

    local old_date=2012-03-16
    local new_date=2012-03-30

    for o in ${old_hv[@]}; do [ $obsid -eq $o ] && dateobs=$old_date; done
    for o in ${new_hv[@]}; do [ $obsid -eq $o ] && dateobs=$new_date; done

    # first HRC-I HV change, test observation
    [ $obsid -eq 62639 ] && dateobs=2021-02-17

    # second HRC-S HV change, test observation
    [ $obsid -eq 62635 ] && dateobs=2021-05-15

    # third HRC-S HV change, "fake" test observation
    [ $obsid -eq 78427 ] && dateobs=2024-09-21
    [ $obsid -eq 78377 ] && dateobs=2024-09-21

    local det
    local detdir

    case "$detnam" in
	ACIS*) det=acis ; detdir=acis ;;
	HRC-S) det=hrcs ; detdir=hrc ;;
	HRC-I) det=hrci ; detdir=hrc ;;
	*) echo "match_caldb_file: unrecognized DETNAM='$detnam'" 1>&2
	   return 1
	   ;;
    esac

    case $# in
	2) dir="$CALDB/data/chandra/$detdir/$type"
	   version=$(latest_caldb_version "$det" "$type" "$dir")
	   ;;
	3) version=$(latest_caldb_version "$det" "$type" "$dir") ;;
	4) : ;;
	*) echo 'Usage: match_caldb_file obsfile type [directory [version]]' 1>&2
	   return 1
	   ;;
    esac

    local files=$(\ls "$dir/$det"*.fits | \egrep ${det}D'[[:digit:]]{4}(-[[:digit:]]{2}){2}'"${type}${version}.fits")

    local cvsd
    local file_last

    for f in $files; do
	cvsd=$(dmkeypar "$f" cvsd0001 echo+)
	cved=$(dmkeypar "$f" cved0001 echo+ 2>/dev/null)

	if [ "$dateobs" \< "$cvsd" ]
	then
	    f="$file_last"

	    #
	    # special cases around the HV testing
	    #
	    if [ false -a "$type" == qe -o "$type" == qeu -o "$type" == t_gmap ]
	    then
		old_hv=( 14324 14396 14397 )
		new_hv=( 14238 )

		old_date=1999-07-22
		new_date=2012-03-29

		[ "$type" == qeu ] && old_date=2012-01-01

		for o in ${old_hv[@]}
		do
		    [ $obsid -eq $o ] && f=$(echo "$f" | sed s/$new_date/$old_date/)
		done

		for o in ${new_hv[@]}
		do
		    [ $obsid -eq $o ] && f=$(echo "$f" | sed s/$old_date/$new_date/)
		done
	    fi

	    echo "$f"
	    return
	fi
	file_last="$f"
    done

    echo "$file_last"
    return

    echo "match_caldb_file: did not find requested file; obsfile=$obsfile; type=$type; dir=$dir; version=$version " 1>&2
    return 1
}

hrcs_latest_qeu_version() {
    latest_caldb_version hrcs qeu $@
}

hrci_latest_qeu_version() {
    latest_caldb_version hrci qeu $@
}

latest_caldb_version() {
    local det="$1" # either hrci, hrcs, or acis
    local type="$2" # e.g., qe or qeu

    local detdir=$det
    case $detdir in
	hrc*) detdir=hrc ;;
	*) ;;
    esac

    local dir
    case $# in
	2) dir="$CALDB/data/chandra/$detdir/$type" ;;
	3) dir="$3" ;;
	*) echo 'Usage: latest_caldb_version det type [directory]' 1>&2
	   return 1
	   ;;
    esac

    local files=$(caldb_files "$dir" "$det" "$type")
    test -z "$files" && return 1
    latest_version_from_caldb_files "$files"
}

caldb_files() {
    local dir="$1"
    local det="$2"
    local type="$3"

    local files=$(\ls "$dir/$det"*.fits | \egrep ${det}D'[[:digit:]]{4}(-[[:digit:]]{2}){2}'"$type"'N[[:digit:]]{4}.fits')

    if [ -z "$files" ]; then
	echo "caldb_files: no files found in '$dir'" 1>&2
	return 1
    fi

    echo "$files"
}

latest_version_from_caldb_files() {
    local files="$1"
    echo "$files" | perl -le '@N=map {/(N\d{4})\.fits/} <>; @N{@N}=(); @N=sort keys %N; print $N[-1]'
}
