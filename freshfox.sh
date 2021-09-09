#!/bin/bash

FRESHFOX_DIR="${HOME}/.local/share/freshfox/"
BROWSER='firefox'
PROFILE_NAME=default
USE_MASTER=''
USE_FIREJAIL=''
XEPHYR_SIZE=1280x960

while getopts "hmjxcp:ld:w:" opt; do
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
			echo "    -x              Use firejail with X11 sandboxing"
			echo "    -c              Use Chromium, not Firefox"
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
			exec ls "${FRESHFOX_DIR}/"
			;;
		d)
			exec rm -r "${FRESHFOX_DIR}/${OPTARG:-default}"
			;;
		x)
			USE_FIREJAIL=x11
			;;
		j)
			USE_FIREJAIL=nox11
			;;
		c)
			BROWSER='chromium'
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

PROFILE_DIR="${FRESHFOX_DIR}/${PROFILE_NAME}/${BROWSER}"

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
			--exclude='/crash*' \
			--exclude='/Crash*' \
			--exclude='/formhistory*' \
			--exclude='/thumbnails*' \
			"${PROFILE_DIR}/" "${SCRATCH_DIR}/"
			#--exclude='/cookies*' \
			#--exclude='/Cookies*' \
			#--exclude='/lock' \
			#--exclude='/LOCK' \
			#--exclude='/Local Storage' \
	fi
	PROFILE_DIR="${SCRATCH_DIR}"
else
	mkdir -p ${PROFILE_DIR}
fi

if [ "${BROWSER}" == 'firefox' ]
then
	if [ "_${USE_FIREJAIL}" == '_x11' ]
	then
		FIREJAIL_X11_OPTS="--x11=xephyr --xephyr-screen=${XEPHYR_SIZE/[^0-9]/x}"
		FIREFOX_X11_OPTS="--window-size ${XEPHYR_SIZE/[^0-9]/,}"
	else
		FIREJAIL_X11_OPTS=
		FIREFOX_X11_OPTS=
	fi
	if [ "x${USE_FIREJAIL}" == 'x' ]
	then
		firefox --no-remote --profile "${PROFILE_DIR}" "$@"
	else
		firejail --name="freshfox-${PROFILE_NAME}" \
					${FIREJAIL_X11_OPTS} \
					--whitelist="${PROFILE_DIR}" \
			firefox \
				--no-remote \
				${FIREFOX_X11_OPTS} \
				--profile "${PROFILE_DIR}" \
				"$@"
	fi
elif [ "${BROWSER}" == 'chromium' ]
then
	if [ "_${USE_FIREJAIL}" == '_x11' ]
	then
		XEPHYR_MAX_X=$((${XEPHYR_SIZE%%[^0-9]*}-1))
		XEPHYR_MAX_Y=$((${XEPHYR_SIZE##*[^0-9]}-1))
		perl -i -pe "s/(?<=\"window_placement\":\\{).*?(?=\\})/\"maximized\":false,\"left\":0,\"top\":0,\"work_area_left\":0,\"work_area_top\":0,\"right\":${XEPHYR_MAX_X},\"work_area_right\":${XEPHYR_MAX_X},\"bottom\":${XEPHYR_MAX_Y},\"work_area_bottom\":${XEPHYR_MAX_Y}/g" "${PROFILE_DIR}/Default/Preferences"
		FIREJAIL_X11_OPTS="--x11=xephyr --xephyr-screen=${XEPHYR_SIZE/[^0-9]/x}"
	else
		perl -i -pe 's/"window_placement":\{.*?\},//' "${PROFILE_DIR}/Default/Preferences"
		FIREJAIL_X11_OPTS=
	fi
	if [ "x${USE_FIREJAIL}" == 'x' ]
	then
		chromium --user-data-dir="${PROFILE_DIR}" "$@"
	else
		firejail --name="freshfox-${PROFILE_NAME}" \
					${FIREJAIL_X11_OPTS} \
					--whitelist="${PROFILE_DIR}" \
			chromium \
				--user-data-dir="${PROFILE_DIR}" \
				"$@"
	fi
else
	echo "unrecognized browser: ${BROWSER}"
	exit 1
fi

