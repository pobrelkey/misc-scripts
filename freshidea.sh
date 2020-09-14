#!/bin/bash

FRESHIDEA_DIR="${HOME}/.local/share/freshidea/"
PROFILE_NAME=default
USE_MASTER=''

while getopts "hmp:ld:" opt; do
	case ${opt} in
		h)
			echo 
			echo "$0 - starts a fresh IntelliJ instance using a separate profile"
			echo 
			echo "Options:"
			echo "    -p <profile>    Use the template profile named <profile> "
			echo "                           (default template profile is called 'default')"
			echo "    -m              Use the profile's master copy, not an ephemeral copy"
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
			exec ls "${FRESHIDEA_DIR}"
			;;
		d)
			exec rm -r "${FRESHIDEA_DIR}/${OPTARG:-default}"
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

PROFILE_DIR="${FRESHIDEA_DIR}/${PROFILE_NAME}"

if [ "x${USE_MASTER}" == 'x' ]
then
	SCRATCH_DIR="$(mktemp -d -t "freshidea.${PROFILE_NAME}.$$.XXXXXXXXXX")"
	function finish {
		rm -rf "${SCRATCH_DIR}"
	}
	trap finish EXIT
	if [ -d "${PROFILE_DIR}" ]
	then
		rsync -aq \
			--exclude='/idea.properties' \
			--exclude='/config/port' \
			--exclude='/config/port.lock' \
			--exclude='/system/caches/names.dat' \
			--exclude='/system/log' \
			--exclude='/system/port' \
			--exclude='/system/port.lock' \
			--exclude='/system/token' \
			"${PROFILE_DIR}/" "${SCRATCH_DIR}/"
	fi
	PROFILE_DIR="${SCRATCH_DIR}"
else
	mkdir -p ${PROFILE_DIR}
fi

IDEA_HOME=$(ls ~/opt/idea/idea-*/bin/idea.sh | sort -rn | sed -E -n -e 's,/bin/idea\.sh,,p;q')

mkdir -p "${PROFILE_DIR}/config" "${PROFILE_DIR}/system"
if [ '!' -f "${PROFILE_DIR}/idea.properties" ]
then
	sed -E \
		-e "s,^.*idea\.config\.path=.*$,idea.config.path=${PROFILE_DIR}/config," \
		-e "s,^.*idea\.system\.path=.*$,idea.system.path=${PROFILE_DIR}/system," \
		-e "s,^.*idea\.log\.path=.*$,idea.log.path=${PROFILE_DIR}/system/log," \
		-e "s,^.*idea\.plugins\.path=.*$,idea.plugins.path=${PROFILE_DIR}/system/plugins," \
		< "${IDEA_HOME}/bin/idea.properties" > "${PROFILE_DIR}/idea.properties"
fi

IDEA_PROPERTIES="${PROFILE_DIR}/idea.properties" \
	"${IDEA_HOME}/bin/idea.sh" "$@"

