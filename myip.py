#!/usr/bin/env python3

# Print out the local IP address your machine uses to access some host.
#
# If no host if specified, prints the IP address used to access
# Google's DNS server, which should give you the local address 
# of your the default interface.
# 
# Note that this will print out your local IP address, not taking
# account of any layers of NAT between you and other parties you
# may want to access your machine.
#
# Written in batteries-included Python.

import argparse, os, socket

remote_host = os.environ.get('MYIP_REMOTE_HOST', '8.8.8.8')

parser = argparse.ArgumentParser(description='Print the local IP address.')
parser.add_argument('host', metavar='HOST', type=str, nargs='?', default=remote_host,
                    help='Print the address on the interface used to contact HOST (default: %s)' % remote_host)
args = parser.parse_args()

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.connect((args.host, 1))

print(s.getsockname()[0])
