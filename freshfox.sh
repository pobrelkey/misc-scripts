#!/bin/bash

FRESHFOX_DIR="${HOME}/.local/share/freshfox/"
PROFILE_NAME=default
USE_MASTER=''
USE_FIREJAIL=''
XEPHYR_SIZE=1280x960

while getopts "hmjp:ld:w:" opt; do
	case ${opt} in
		h)
			echo 
			echo "$0 - starts a fresh Firefox instance using a separate profile"
			echo 
			echo "Options:"
			echo "    -p <profile>    Use the template profile named <profile> "
			echo "                           (default template profile is called 'default')"
			echo "    -m              Use the profile's master copy, not an ephemeral copy"
			echo "    -j              Use firejail to increase browser security"
			echo "    -w              Use custom firejail window size (default: ${XEPHYR_SIZE})"
			echo "    -l              List template profiles"
			echo "    -d <profile>    Delete the given template profile"
			echo "    -h              Display this help message"
			echo 
			exit 0
			;;
		m)
			USE_MASTER=1
			;;
		p)
			PROFILE_NAME=${OPTARG:-default}
			;;
		l)
			exec ls "${FRESHFOX_DIR}"
			;;
		d)
			exec rm -r "${FRESHFOX_DIR}/${OPTARG:-default}"
			;;
		j)
			USE_FIREJAIL=1
			;;
		w)
			XEPHYR_SIZE=${OPTARG:-1280x960}
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

PROFILE_DIR="${FRESHFOX_DIR}/${PROFILE_NAME}"

if [ "x${USE_MASTER}" == 'x' ]
then
	SCRATCH_DIR="$(mktemp -d -t "freshfox.${PROFILE_NAME}.$$.XXXXXXXXXX")"
	function finish {
		rm -rf "${SCRATCH_DIR}"
	}
	trap finish EXIT
	if [ -d "${PROFILE_DIR}" ]
	then
		rsync -aq \
			--exclude='/*backups' \
			--exclude='/*cache*' \
			--exclude='/*Cache*' \
			--exclude='/cookies*' \
			--exclude='/crashes' \
			--exclude='/formhistory*' \
			--exclude='/lock' \
			--exclude='/thumbnails*' \
			"${PROFILE_DIR}/" "${SCRATCH_DIR}/"
	fi
	PROFILE_DIR="${SCRATCH_DIR}"
else
	mkdir -p ${PROFILE_DIR}
fi

if [ "x${USE_FIREJAIL}" == 'x' ]
then
	firefox --no-remote --profile "${PROFILE_DIR}" "$@"
else
	firejail --name="freshfox-${PROFILE_NAME}" \
                --x11=xephyr --xephyr-screen=${XEPHYR_SIZE/[^0-9]/x} \
                --whitelist="${PROFILE_DIR}" \
		firefox \
			--no-remote \
			--window-size ${XEPHYR_SIZE/[^0-9]/,} \
			--profile "${PROFILE_DIR}" \
			"$@"
fi


