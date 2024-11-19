import argparse
import datetime
import numpy as np
import re
import subprocess
import sys

def main():
    parser = argparse.ArgumentParser(
        description='Print HRC obsids.' 
    )
    parser.add_argument('--start', default='1999-07-22', help='Start date.')
    parser.add_argument('--stop', default=datetime.datetime.utcnow().strftime('%Y-%m-%d'), help='Stop date.')
    args = parser.parse_args()

    p = re.compile(r'^\d{4}-\d{2}-\d{2}$')
    if not p.match(args.start) or not p.match(args.stop):
        raise('start/stop must be formatted YYYY-MM-DD')

    print(' '.join(obsids(args.start, args.stop)))

def obsids(start, stop):

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
    return re.findall(r'hrcf(\d{5})_.*evt1.fits', output)

if __name__ == '__main__':
  main()
