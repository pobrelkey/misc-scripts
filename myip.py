#!/usr/bin/env python

import argparse, os, socket

remote_host = os.environ.get('MYIP_REMOTE_HOST', '8.8.8.8')

parser = argparse.ArgumentParser(description='Print the local IP address.')
parser.add_argument('host', metavar='HOST', type=str, nargs='?', default=remote_host,
                    help='Print the address on the interface used to contact HOST (default: %s)' % remote_host)
args = parser.parse_args()

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.connect((args.host, 1))

print(s.getsockname()[0])
