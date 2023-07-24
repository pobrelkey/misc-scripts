#!/usr/bin/env bash


#
# Create a bare Git repository at an rclone remote URL, for use with
# git-remote-rclone-sync.
#
# (For git-remote-rclone-sync to work on cloud storage providers like S3
# with no concept of empty directories, you need to ensure the remote
# repository contains at least one commit, otherwise git won't recognize
# it as a valid repository.  This script creates a bare repository with
# a single commit - a README.md in the style of GitHub's stub READMEs -
# and copies it to the remote location.)
#
# Usage example:
#   git-create-rclone-remote.sh rclone_remote_name:path/to/repos.git "Description of the repository"
#


set -e

SCRIPT_TMPDIR="${TMPDIR:-/tmp}/git-create-rclone-remote-$$"

cleanup() {
	if [ -d "${SCRIPT_TMPDIR}" ]
	then
		rm -rf "${SCRIPT_TMPDIR}"
	fi
}
trap cleanup EXIT

REMOTE_URL="$1"
REPOS_NAME="$(basename "${1##*:}" .git)"
shift

mkdir -p "${SCRIPT_TMPDIR}"

TMP_BARE_REPOS="${SCRIPT_TMPDIR}/repos"
git init --bare "${TMP_BARE_REPOS}"

TMP_WORKING_DIR="${SCRIPT_TMPDIR}/work"
git clone "${TMP_BARE_REPOS}" "${TMP_WORKING_DIR}" 2>/dev/null
(
	echo
	echo "# ${REPOS_NAME}"
	echo
	echo "$@"
	echo
) > "${TMP_WORKING_DIR}"/README.md

(
	cd "${TMP_WORKING_DIR}"
	git add README.md
	git commit -m 'initial commit'
	git push
)

rclone sync --create-empty-src-dirs "${TMP_BARE_REPOS}/" "${REMOTE_URL%/}/"

