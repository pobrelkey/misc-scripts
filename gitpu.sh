#!/usr/bin/env bash

#
#  Commit what's on the current git working branch,
#  then push it upstream if that's straightforward.
#


set -e

#ORIGIN_BRANCH="$(git for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD) | head -n 1)"
#ORIGIN_BRANCH="$(git rev-parse --abbrev-ref HEAD@{upstream})"

git commit "$@"

git fetch

if ( git rebase )
then
	git push
else
	git rebase --abort
	exit 1
fi



