import argparse
import astropy.io.fits
import numpy as np
import os
import sys

import numpy as np

# # from https://www.google.com/search?q=astropy.io.fits+bitfield
# # Define 5 bits of data per row for 3 rows
# # 5 bits will automatically be stored as 1 byte (8 bits) in the FITS structure
# data_bits = np.array([
#     [1, 0, 1, 0, 0],  # Row 1
#     [0, 1, 1, 0, 1],  # Row 2
#     [1, 1, 0, 0, 0]   # Row 3
# ], dtype=bool)

# # Create the bitfield column using '5X'
# bit_col = fits.Column(name='QUALITY_FLAGS', format='5X', array=data_bits)

# # Wrap it in a Binary Table HDU
# hdu = fits.BinTableHDU.from_columns([bit_col])
# hdu.writeto('bitfield_example.fits', overwrite=True, checksum=True)

def tailgate_flag(args):
    infile = args.infile
    outfile = args.outfile
    dt_lim = args.dt_lim
    rad_lim = args.rad_lim

    with astropy.io.fits.open(infile) as hdulist:
        data = hdulist['events'].data
        time = data['time']
        x = data['chipx']
        y = data['chipy']
        flag = np.zeros((time.size,1), dtype=bool)

        for i in range(time.size-2):
            j = i+1
            if j < time.size:
                while (time[j]-time[i]) < dt_lim:
                    if np.sqrt((x[j]-x[i])**2+(y[j]-y[i])**2) < rad_lim:
                        flag[j][0] = True
                    j = j+1
                    if j == time.size:
                        break
        bit_col = astropy.io.fits.Column(name='TAILGATE', format='1X', array=flag)
        hdu = astropy.io.fits.BinTableHDU.from_columns([bit_col])
        print(outfile)
        hdu.writeto(outfile, overwrite=True, checksum=True)

def main():
    parser = argparse.ArgumentParser(
        description='Flag tailgate events.'
    )
    parser.add_argument('--dt_lim', default=0.05, help='deltatime limit')
    parser.add_argument('--rad_lim', default=20, help='radius limit')
    parser.add_argument('infile', help='Input EVT1 file.')
    parser.add_argument('outfile', help='Output FITS file.')
    args = parser.parse_args()

    tailgate_flag(args)

if __name__ == '__main__':
    main()
