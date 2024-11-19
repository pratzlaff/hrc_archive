#! /bin/bash

indir=/data/legs/rpete/flight/rmfs
outdir=/data/loss/rpete/hrc/rmfs

mkdir -p $outdir

for tg_m in {1..10}
do
  cp -a $indir/HRC-S-LEG_-${tg_m}.rmf $outdir/rmf_hrcs_leg_m${tg_m}.fits
  cp -a $indir/HRC-S-LEG_${tg_m}.rmf $outdir/rmf_hrcs_leg_p${tg_m}.fits
done

tg_m=1
for arm in LEG MEG HEG
do
  cp -a $indir/HRC-I-${arm}_-${tg_m}.rmf $outdir/rmf_hrci_${arm,,}_m${tg_m}.fits
  cp -a $indir/HRC-I-${arm}_${tg_m}.rmf $outdir/rmf_hrci_${arm,,}_p${tg_m}.fits
done
