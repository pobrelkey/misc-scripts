#!/bin/bash

JAILBIRD_DIR="${HOME}/.local/share/jailbird/"
PROFILE_NAME=default
XEPHYR_SIZE=1280x960
JAIL_X11=

while getopts "hp:ld:w:x" opt; do
	case ${opt} in
		h)
			echo 
			echo "$0 - starts Thunderbird in a security jail"
			echo 
			echo "Options:"
			echo "    -x              Use nested Xephyr X11 server"
			echo "    -w              Use custom firejail window size (default: ${XEPHYR_SIZE})"
			echo "    -p <profile>    Use the profile named <profile> "
			echo "                           (default profile is called 'default')"
			echo "    -l              List profiles"
			echo "    -d <profile>    Delete the given profile"
			echo "    -h              Display this help message"
			echo 
			exit 0
			;;
		p)
			PROFILE_NAME=${OPTARG:-default}
			;;
		l)
			exec ls "${FRESHFOX_DIR}/"
			;;
		d)
			exec rm -r "${FRESHFOX_DIR}/${OPTARG:-default}"
			;;
		w)
			XEPHYR_SIZE=${OPTARG:-1280x960}
			JAIL_X11=1
			;;
		x)
			JAIL_X11=1
			;;
		\?)
			echo "Invalid Option: -$OPTARG" 1>&2
			exit 1
			;;
		:)
			echo "Invalid Option: -$OPTARG requires an argument" 1>&2
			exit 1
			;;
	esac
done
shift $((OPTIND -1))

cd

PROFILE_DIR="${JAILBIRD_DIR}/${PROFILE_NAME}"

mkdir -p ${PROFILE_DIR}

if [ "_${JAIL_X11}" != '_' ]
then
	FIREJAIL_X11_OPTS="--x11=xephyr --xephyr-screen=${XEPHYR_SIZE/[^0-9]/x}"
	THUNDERBIRD_X11_OPTS="--window-size ${XEPHYR_SIZE/[^0-9]/,}"
else
	FIREJAIL_X11_OPTS=
	THUNDERBIRD_X11_OPTS=
fi
firejail --name="jailbird-${PROFILE_NAME}" \
			${FIREJAIL_X11_OPTS} \
			--whitelist="${PROFILE_DIR}" \
	thunderbird \
		${THUNDERBIRD_X11_OPTS} \
		--profile "${PROFILE_DIR}" \
		"$@"
