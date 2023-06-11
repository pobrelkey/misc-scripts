#!/usr/bin/env bash

#
#  Obscure a password, or print an un-obscured password to stdout.
#
#  Useful when used in the RCLONE_PASSWORD_COMMAND environment variable.
#

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
	tr 'A-Za-z0-9' 'n-zA-Za-m5-90-4' <<<"${PASSWD_1}" | base64
else
	base64 -d <<<"${1}" | tr 'A-Za-z0-9' 'N-Za-zA-M5-90-4'
fi

