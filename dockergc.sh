#!/bin/sh

#
#  Removes all but the most recently created version per repository
#  for of Docker images.
#
#  Usage: dockergc.sh [-f|--force] [--filter=SPEC] [REPOSITORY]
#


FORCE=
if [ "$1" = '-f' ] || [ "$1" = '--force' ]
then
	shift
	FORCE=-f
fi

echo docker image rm ${FORCE} $(\
		docker image ls "$@" --format='table {{.ID}}\t{{.Repository}}' \
			| awk '{ if ($2 in a) { print $1 } else { a[$2] = $1 } }' \
	)
