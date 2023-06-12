#!/usr/bin/env bash

#
#  Obfuscate a sensitive value, or print a de-obfuscated value to stdout.
#
#  Obfuscated values "expire" after 64 seconds, and are encoded in a
#  manner which uses some (public and not very unique) machine-specific
#  info, to frustrate replay/copy-paste attacks.  This isn't remotely
#  close to proper security though.
#
#  Useful when used in the RCLONE_PASSWORD_COMMAND environment variable.
#

set -e

NOW=$( date +%s )

if [[ -z "${1}" ]]
then
	read -s -p "Enter password: " PASSWD_1
	echo
	read -s -p "Again: " PASSWD_2
	echo
	if [[ "${PASSWD_1}" != "${PASSWD_2}" ]]
	then
		echo "ERROR: passwords don't match"
		exit 1
	fi

	NOW_MOD64_B64="$(printf '%02x' $(( (${NOW} & 63) << 2 )) | xxd -p -r | base64)"
	echo -n ${NOW_MOD64_B64:0:1}
	
	openssl enc -a -aes-256-cbc -pbkdf2 -pass fd:3 \
			3<<<"${NOW}:M4r10:$(uname -a):Lu1g1" \
			<<<"${PASSWD_1}" \
		| tr -d '\n'
	echo
else
	THEN_MOD64=$(( 0x$( base64 -d <<<"${1:0:1}A==" | xxd -p ) >> 2 ))
	THEN=$(( ( ${NOW} & 0xffffffc0 ) + ${THEN_MOD64} ))
	if [[ ${THEN} -gt ${NOW} ]]
	then
		THEN=$(( ${THEN} - 64 ))
	fi
	
	openssl enc -d -a -aes-256-cbc -pbkdf2 -pass fd:3 \
			3<<<"${THEN}:M4r10:$(uname -a):Lu1g1" \
			<<<"${1:1}"
fi

