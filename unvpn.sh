#!/usr/bin/env bash

#
#  When using a VPN which is used as the machine's default route,
#  add/remove a one-off route to some specific address which goes
#  via the LAN interface rather than via the VPN (thereby forgoing
#  VPN protection for that address).
#
#  Usage: unvpn.sh [add|del] address [address...]
#

set -e

if ( [ "$1" == 'add' ] || [ "$1" == 'up' ] )
then
	OP=add
	shift
elif ( [ "$1" == 'del' ] || [ "$1" == 'down' ] )
then
	OP=del
	shift
else
	OP=add
fi

if [ "$1" == '' ]
then
	echo "usage: ${0} [add|del] DESTINATION [DESTINATION...]"
	exit 1
fi

ROUTE="$(sudo route -4)"
VPN_METRIC=$(echo "${ROUTE}" | perl -ane 'BEGIN { $x = 100 }; if ($F[0] eq "default" && $F[1] eq "0.0.0.0" && $F[4] < $x) { $x = $F[4] }; END { print "$x\n" }')
LAN_GW=$(echo "${ROUTE}" | perl -ane 'BEGIN { $x = 99999; $y = "" }; if ($F[0] eq "default" && $F[1] ne "0.0.0.0" && $F[4] < $x) { $x = $F[4]; $y=$F[1] }; END { print "$y\n" }')
LAN_IFACE=$(echo "${ROUTE}" | perl -ane 'BEGIN { $x = 99999; $y = "" }; if ($F[0] eq "default" && $F[1] ne "0.0.0.0" && $F[4] < $x) { $x = $F[4]; $y=$F[7] }; END { print "$y\n" }')

while [ "$1" != '' ]
do
	if [[ "$1" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]
	then
		DESTS="$1"
	else
		DESTS="$(host -t A "$1" | grep -Po '(?<= has address )\d+\.\d+\.\d+\.\d+')"
	fi
	for DEST in ${DESTS}
	do
		sudo route ${OP} -host ${DEST} metric $(( ${VPN_METRIC} - 1 )) dev ${LAN_IFACE} gw ${LAN_GW}
	done
	shift
done

