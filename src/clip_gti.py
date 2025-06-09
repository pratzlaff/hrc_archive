import argparse
import astropy.io.fits as fits
import numpy as np

def clip_gti(args):

    with fits.open(args.archgti) as hdulist:
        arch_start = hdulist['gti'].data['start'][0]

    with fits.open(args.phsgti) as hdulist:
        start = hdulist['gti'].data['start']
        stop = hdulist['gti'].data['stop']

        start[0] = arch_start

        # FIXME: this can happen if a start/stop are both less than
        # archival start
        if stop[0]<start[0]:
            raise IOError(f'stop[0]={stop[0]} < start[0]={start[0]}')

        hdulist.writeto(args.outgti, overwrite=True, checksum=True)

def main():
    parser = argparse.ArgumentParser(
        description='Clip patch_hrc_ssc GIT START[0], according to archival START[0].'
    )
    parser.add_argument('archgti', help='Archival std_flt1.')
    parser.add_argument('phsgti', help='patch_hrc_ssc output std_flt1.')
    parser.add_argument('outgti', help='New, clipped std_flt1.')
    args = parser.parse_args()

    clip_gti(args)

if __name__ == '__main__':
    main()
