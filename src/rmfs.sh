#! /bin/bash

indir=/data/legs/rpete/flight/rmfs
outdir=/data/loss/rpete/hrc/rmfs

mkdir -p $outdir

for tg_m in {1..10}
do
  for arm in LEG
  do
    cp -a $indir/HRC-S-${arm}_-${tg_m}.rmf $outdir/hrcs_${arm,,}_m${tg_m}.rmf
    cp -a $indir/HRC-S-${arm}_${tg_m}.rmf $outdir/hrcs_${arm,,}_p${tg_m}.rmf
  done
done

tg_m=1
for arm in LEG MEG HEG
do
  cp -a $indir/HRC-I-${arm}_-${tg_m}.rmf $outdir/hrci_${arm,,}_m${tg_m}.rmf
  cp -a $indir/HRC-I-${arm}_${tg_m}.rmf $outdir/hrci_${arm,,}_p${tg_m}.rmf
done
