#!/usr/bin/env bash

#
#  Commit what's on the current git working branch,
#  then push it upstream if that's straightforward.
#


set -e

git commit "$@"

git fetch

if ( git rebase )
then
	git push
else
	git rebase --abort
	exit 1
fi



