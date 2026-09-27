import argparse
import astropy.io.fits
import sys

def get_ttype(hdr, keyword):
    for i in range(1, len(hdr)+1):
        try:
            if hdr[f'ttype{i}'].lower() == keyword:
                return i
        except:
            raise

def get_deroll_wcs(evt2):
    with astropy.io.fits.open(evt2) as hdulist:
        hdr = hdulist['events'].header

        x = get_ttype(hdr, 'x')
        y = get_ttype(hdr, 'y')

        data = { 'ttype' : { 'x' : x,
                             'y' : y,
                            },
                }
        for w in 'tform', 'tunit', 'tlmin', 'tlmax', 'tctyp', 'tcrvl', 'tcrpx', 'tcdlt', 'tcuni':
            data[w] = { 'x' : hdr[f'{w}{x}'], 'y' : hdr[f'{w}{y}'] }

        return data

def count_keywords(hdr, basename):
        keywords = 0

        for i in range(1, len(hdr)+1):
            if f'{basename}{i}' in hdr:
                keywords = i
            else:
                return keywords

def addwcs(args):

    wcs = get_deroll_wcs(args.evt2_deroll_wcs)
    with astropy.io.fits.open(args.evt2) as hdulist:
        hdr = hdulist['events'].header

        mtypes = count_keywords(hdr, 'mtype')
        ttypes = count_keywords(hdr, 'ttype')

        xderoll = get_ttype(hdr, 'xderoll')
        yderoll = get_ttype(hdr, 'yderoll')

        hdr[f'MTYPE{mtypes+1}'] = 'sky_deroll'
        hdr[f'MFORM{mtypes+1}'] = 'xderoll,yderoll',

        hdr[f'TCTYP{xderoll}'] = wcs['tctyp']['x']
        hdr[f'TCRVL{xderoll}'] = wcs['tcrvl']['x']
        hdr[f'TCRPX{xderoll}'] = wcs['tcrpx']['x']
        hdr[f'TCDLT{xderoll}'] = wcs['tcdlt']['x']
        hdr[f'TCUNI{xderoll}'] = wcs['tcuni']['x']

        hdr[f'TCTYP{yderoll}'] = wcs['tctyp']['y']
        hdr[f'TCRVL{yderoll}'] = wcs['tcrvl']['y']
        hdr[f'TCRPX{yderoll}'] = wcs['tcrpx']['y']
        hdr[f'TCDLT{yderoll}'] = wcs['tcdlt']['y']
        hdr[f'TCUNI{yderoll}'] = wcs['tcuni']['y']

        hdulist.writeto(args.outfile, overwrite=True, checksum=True)

def main():
    parser = argparse.ArgumentParser(
        description='Add WCS info for deroll columns'
    )
    parser.add_argument('evt2_deroll_wcs', help='Input event list with derolled coordinates.')
    parser.add_argument('evt2', help='Input event list with derolled coordinates.')
    parser.add_argument('outfile', help='Output FITS file.')
    args = parser.parse_args()

    addwcs(args)

if __name__ == '__main__':
    main()
