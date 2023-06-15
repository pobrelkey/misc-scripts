#!/usr/bin/env bash

#
#  RVS - the rclone versatile syncer
#
#  Script that enhances "rclone sync" with some overwrite-safety and
#  a UX roughly like the bits of git you can remember while drunk.
#
#  Called "RVS" as that sounds like a old, clunky, feature-poor
#  version-control system (which nearly describes this script).
#

set -e


CMD_NAME="$(basename "$0")"
SUBCMD_NAME="${1}"

SUMMARY_INIT="prepare a working directory for use with ${CMD_NAME}"
SUMMARY_CLONE='initialize a working directory with content from remote'
SUMMARY_PULL='take changes from remote storage'
SUMMARY_PUSH='send changes to remote storage'
SUMMARY_STATUS='show which files differ from remote and last pull/push'
SUMMARY_TOUCHED='view list of files altered since last pull/push'
SUMMARY_REMOTE='view or alter remote storage configuration'

make_working_dir() {
	if [[ -e "${RVS_DIR}" ]] && [[ "${1}" != 1 ]]
	then
		echo "${CMD_NAME} ${SUBCMD_NAME}: ${RVS_DIR} is already a working directory" 1>&2
		exit 1
	fi
	mkdir -p "${RVS_DIR}/remotes"

	echo '[]' > "${RVS_DIR}/metadata.json"
}

find_rvs_dir() {
	CANDIDATE_DIR="$(realpath "${1:-.}")"
	while [[ ! -d "${CANDIDATE_DIR}/.rvs" ]]
	do
		if [[ "${CANDIDATE_DIR}" == / ]]
		then
			echo "${CMD_NAME} ${SUBCMD_NAME}: no ancestor directory is a working directory" 1>&2
			exit 1
		fi
		CANDIDATE_DIR="$(dirname "${CANDIDATE_DIR}")"
	done
	RVS_ROOT="${CANDIDATE_DIR}"
	RVS_DIR="${RVS_ROOT}/.rvs"
}





init_usage() {
	echo "${CMD_NAME} ${SUBCMD_NAME} - ${INIT_SUMMARY}"
	echo
	echo 'usage:'
	echo "    ${CMD_NAME} ${SUBCMD_NAME} [-f|--force] [LOCAL_DIR]"
	echo "    ${CMD_NAME} ${SUBCMD_NAME} [-h|--help]"
	echo
	echo 'options:'
	echo '    -f, --force'
	echo '        Force checkout - skip checks on destination directory'
	echo '    -h, --help'
	echo '        show this Help message'
}

init() {
	FORCE=0
	if [[ "${1}" == -f ]] || [[ "${1}" == --force ]] 
	then
		FORCE=1
		shift
	fi
	if [[ "${1}" == -h ]] || [[ "${1}" == --help ]]
	then
		init_usage
		exit 0
	fi
	if [[ $# -gt 1 ]]
	then
		init_usage 1>&2
		exit 1
	fi

	RVS_ROOT="$(realpath "${1:-.}")"
	RVS_DIR="${RVS_ROOT}/.rvs"
	make_working_dir ${FORCE}

	exit 0
}

clone_usage() {
	echo "${CMD_NAME} ${SUBCMD_NAME} - ${CLONE_SUMMARY}"
	echo
	echo 'usage:'
	echo "    ${CMD_NAME} ${SUBCMD_NAME} [-f|--force] REMOTE_URL [LOCAL_DIR]"
	echo "    ${CMD_NAME} ${SUBCMD_NAME} [-h|--help]"
	echo
	echo 'options:'
	echo '    -f, --force'
	echo '        Force checkout - skip checks on destination directory'
	echo '    -h, --help'
	echo '        show this Help message'
}

clone() {
	FORCE=0
	if [[ "${1}" == -f ]] || [[ "${1}" == --force ]] 
	then
		FORCE=1
		shift
	fi
	if [[ "${1}" == -h ]] || [[ "${1}" == --help ]]
	then
		clone_usage
		exit 0
	fi
	if [[ $# -gt 2 ]] || [[ $# -eq 0 ]]
	then
		clone_usage 1>&2
		exit 1
	fi

	REMOTE_URL="${1}"
	RVS_ROOT="$(realpath "${2:-.}")"
	if [[ -e "${RVS_ROOT}" ]] && [[ "${FORCE}" != 1 ]] && ( find "${RVS_ROOT}" -mindepth 1 | grep -Eq '.' )
	then
		echo "${CMD_NAME} ${SUBCMD_NAME}: cannot clone into a non-empty directory" 1>&2
		exit 1
	fi

	RVS_DIR="${RVS_ROOT}/.rvs"
	make_working_dir ${FORCE}

	echo "${REMOTE_URL}" > "${RVS_DIR}/remotes/origin"

	rclone copy \
		--create-empty-src-dirs \
		--ignore "${REMOTE_URL#*:}/.rvs" \
		"${REMOTE_URL}/" "${RVS_ROOT}/"

	rclone lsjson -R \
		--ignore "${RVS_ROOT}/.rvs" \
		--config /dev/null "${RVS_ROOT}" \
		> "${RVS_DIR}/metadata.json"

	exit 0
}

remote_usage() {
	echo "${CMD_NAME} ${SUBCMD_NAME} - ${CLONE_SUMMARY}"
	echo
	echo 'usage:'
	echo "    ${CMD_NAME} ${SUBCMD_NAME}"
	echo '        list current remote mapping names'
	echo "    ${CMD_NAME} ${SUBCMD_NAME} add NAME URL"
	echo '        add a new remote mapping'
	echo "    ${CMD_NAME} ${SUBCMD_NAME} delete NAME"
	echo '        delete a remote mapping'
	echo "    ${CMD_NAME} ${SUBCMD_NAME} rename OLD_NAME NEW_NAME"
	echo '        change the name of a remote mapping'
	echo "    ${CMD_NAME} ${SUBCMD_NAME} get-url NAME"
	echo '        print the URL of a remote mapping'
	echo "    ${CMD_NAME} ${SUBCMD_NAME} set-url NAME URL"
	echo '        set the URL of a remote mapping'
	echo "    ${CMD_NAME} ${SUBCMD_NAME} [show|-v]"
	echo '        list current remote mapping names and corresponding URLs'
	echo "    ${CMD_NAME} ${SUBCMD_NAME} [-h|--help]"
	echo '        show this help message'
}

remote() {
	find_rvs_dir

	if [[ $# -eq 0 ]]
		ls "${RVS_DIR}/remotes"
		exit 0
	fi
	case "${1}" in
		add)
			if [[ $# -ne 2 ]]
			then
				remote_usage 1>&2
				exit 1
			fi
			if [[ -e "${RVS_DIR}/remotes/${1}" ]]
			then
				echo "${CMD_NAME} ${SUBCMD_NAME}: remote ${1} already exists" 1>&2
				exit 1
			fi
			echo -n "${2}" > "${RVS_DIR}/remotes/${1}"
			exit 0
			;;
		delete)
			if [[ $# -ne 1 ]]
			then
				remote_usage 1>&2
				exit 1
			fi
			if [[ ! -e "${RVS_DIR}/remotes/${1}" ]]
			then
				echo "${CMD_NAME} ${SUBCMD_NAME}: remote ${1} does not exist" 1>&2
				exit 1
			fi
			rm "${RVS_DIR}/remotes/${1}"
			exit 0
			;;
		rename)
			if [[ $# -ne 2 ]]
			then
				remote_usage 1>&2
				exit 1
			fi
			if [[ ! -e "${RVS_DIR}/remotes/${1}" ]]
			then
				echo "${CMD_NAME} ${SUBCMD_NAME}: remote ${1} does not exist" 1>&2
				exit 1
			fi
			if [[ -e "${RVS_DIR}/remotes/${2}" ]]
			then
				echo "${CMD_NAME} ${SUBCMD_NAME}: remote ${2} already exists" 1>&2
				exit 1
			fi
			mv "${RVS_DIR}/remotes/${1}" "${RVS_DIR}/remotes/${2}"
			exit 0
			;;
		get-url)
			if [[ $# -ne 1 ]]
			then
				remote_usage 1>&2
				exit 1
			fi
			if [[ ! -e "${RVS_DIR}/remotes/${1}" ]]
			then
				echo "${CMD_NAME} ${SUBCMD_NAME}: remote ${1} does not exist" 1>&2
				exit 1
			fi
			cat "${RVS_DIR}/remotes/${1}"
			exit 0
			;;
		set-url)
			if [[ $# -ne 2 ]]
			then
				remote_usage 1>&2
				exit 1
			fi
			if [[ ! -e "${RVS_DIR}/remotes/${1}" ]]
			then
				echo "${CMD_NAME} ${SUBCMD_NAME}: remote ${1} does not exist" 1>&2
				exit 1
			fi
			echo -n "${2}" > "${RVS_DIR}/remotes/${1}"
			exit 0
			;;
		show|-v)
			if [[ $# -ne 1 ]]
			then
				remote_usage 1>&2
				exit 1
			fi
			(
				cd "${RVS_DIR}/remotes"
				for REMOTE in *
				do
					printf '%-10s  %s\n' "${REMOTE}" "$(< ${REMOTE})"
				done
			)
			exit 0
			;;
		-h|--help)
			remote_usage
			exit 0
			;;
		*)
			remote_usage 1>&2
			exit 1
			;;
	esac
}

touched() {
	echo 'TODO: WRITE ME'
	exit 1
# rvs touched [LOCAL_PATH]...
	# list un-ignored local files where metadata doesn't match ROOT/.rvs/metadata.json
		# + added
		# - deleted
		# * changed
}

pull() {
	echo 'TODO: WRITE ME'
	exit 1
# rvs pull [-f] [-r REMOTE] [-a] [LOCAL_PATH]...
	# sync down - make local match remote
		# force mode (-f):
			# just exclude .rvsignore'd files
		# regular mode:
			# also exclude "touched" files
	# update ROOT/.rvs/metadata.json for pulled files
}

status() {
	echo 'TODO: WRITE ME'
	exit 1

# rvs status [-r REMOTE] [LOCAL_PATH]...
	# run "rclone check --combined - | grep -Ev '^= '" for un-ignored local files
		# ...or do we do proper conflict detection? (see below)
# status...
	# +> added locally
	# +< added remotely
	# -< deleted remotely
	# -> deleted locally
	# *< changed remotely
	# *> changed locally
	# -! changed remotely, deleted locally
	# +! deleted remotely, changed locally
	# *! changed remotely, changed locally
	# *! added remotely, added locally
}

push() {
	echo 'TODO: WRITE ME'
	exit 1
# rvs push [-f] [-r REMOTE] [-a] [LOCAL_PATH]...
	# sync up - make remote match local
		# force mode (-f):
			# just exclude .rvsignore'd files
		# regular mode:
			# also exclude files where stored, local, remote metadata all differ
				# requires call to "rclone lsjson -R", then complex jq merge
		# --log-file [TMPFILE] --use-json-log
	# update ROOT/.rvs/metadata.json for pushed files
}

usage() {
	echo 'rvs - the Rclone Versatile Syncer'
	echo
	echo "usage: ${CMD_NAME} COMMAND [ARGS]"
	echo
	echo 'Where COMMAND is one of:'
	echo "    init    - ${SUMMARY_INIT}"
	echo "    clone   - ${SUMMARY_CLONE}"
	echo "    pull    - ${SUMMARY_PULL}"
	echo "    push    - ${SUMMARY_PUSH}"
	echo "    status  - ${SUMMARY_STATUS}"
	echo "    touched - ${SUMMARY_TOUCHED}"
	echo "    remote  - ${SUMMARY_REMOTE}"
	echo
	echo "For individual command help, run: ${CMD_NAME} COMMAND --help"
}



######## main ########

case "${SUBCMD_NAME}" in
	init|clone|remote|pull|push|status|touched)
		"$@"
		exit 0
		;;
	-h|--help)
		usage
		exit 0
		;;
esac

usage 1>&2
exit 1


