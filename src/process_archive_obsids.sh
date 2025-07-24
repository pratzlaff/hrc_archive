#! /bin/bash

# process set i of n for either I or S detector

set -eo pipefail

[ $# -gt 0 ] || {
  \echo "Usage: outdir [obsid1 obsid2 ...]" 1>&2
  exit 1
}

outdir="$1"
[ -d "$outdir" ] || {
  echo "directory does not exist, exiting: '$outdir'" 1>&2
  exit 1
}
shift

obsids="$@"
emails='pratzlaff@cfa.harvard.edu'

script=/data/legs/rpete/flight/hrc_archive/src/hrc_archive_repro.sh
logdir="$outdir/incomplete"
mkdir -p "$logdir"

nobsids=$(\echo $obsids | wc -w)

[ $nobsids -eq 0 ] && {
  \echo There are no ObsIDs to process.
  exit
}

msg="Processing $nobsids ObsID"
[ $nobsids -gt 1 ] && {
    msg+=s
}
msg+=":\n"$(echo $obsids | perl -anle 'print "\t$_" for @F')"\n"
echo -e "$msg"

j=0
for obsid in $obsids
do
  (( ++j ))
  obsid=$(printf %05d $(sed s/^0*// <<<$obsid))
  \echo "********** Processing ObsID $obsid: $j of $nobsids **********" 1>&2
  true && {
    bash -x $script $obsid $outdir 2>&1 | tee "$logdir/hrc_archive_repro.log.$obsid"
  } || {
    echo "bash -x $script $obsid $outdir 2>&1 | tee \"$logdir/hrc_archive_repro.log.$obsid\""
  }

  # in cases where there was not data downloaded, there won't be [is]/$obsid directory
  for subdet in i s
  do
    testdir="$outdir/$subdet/$obsid"
    [ -d "$testdir" ] && mv "$logdir/hrc_archive_repro.log.$obsid" "$testdir/hrc_archive_repro.log"
  done
done

false && {
  for email in $emails
  do
    echo -e "Processed $nobsids ObsIDs:\n${obsids_str}" | mailx '-sprocess_archive_obsids.sh finished' "$email"
  done
}

