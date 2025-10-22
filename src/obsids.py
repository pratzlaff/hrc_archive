import argparse
from datetime import datetime, timedelta
import numpy as np
import os
import re
import subprocess
import sys

def main():
    parser = argparse.ArgumentParser(
        description='Print HRC obsids.' 
    )
    parser.add_argument('--start', default=(datetime.utcnow()-timedelta(weeks=2)).strftime('%Y-%m-%d'), help='Start date.')
    parser.add_argument('--stop', default=datetime.utcnow().strftime('%Y-%m-%d'), help='Stop date.')
    parser.add_argument('--basedir', default='/data/loss/rpete/hrc', help='Where to look for existing reprocessed data.')
    parser.add_argument('--ignore_existing', default=True, action=argparse.BooleanOptionalAction, help='Ignore existing ObsIDs in basedir.')
    args = parser.parse_args()

    p = re.compile(r'^\d{4}-\d{2}-\d{2}$')
    if not p.match(args.start) or not p.match(args.stop):
        raise('start/stop must be formatted YYYY-MM-DD')

    print(' '.join(obsids(args)))

def obsids(args):
    start = args.start
    stop = args.stop

    input = f'''
operation=browse
dataset=flight
detector=hrc
filetype=evt1
level=1
tstart={start}T00:00:00
tstop={stop}T00:00:00
go
    '''
    p = subprocess.Popen(
        ['/proj/axaf/simul/bin/arc5gl', '-stdin'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
    )   
    output = p.communicate(input=input.encode())[0].decode()
    obsids = re.findall(r'hrcf(\d{5})_.*evt1.fits', output)
    if args.ignore_existing:
        obsids = filter_existing(obsids, args.basedir)
    return obsids

def filter_existing(obsids, basedir):
    return [o for o in obsids if not os.path.isdir(f'{basedir}/s/{o}') and not os.path.isdir(f'{basedir}/i/{o}')]
    return obsids

if __name__ == '__main__':
  main()
