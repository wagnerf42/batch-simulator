#!/bin/sh
git rev-parse --verify HEAD >/dev/null || exit 1
git update-index -q --ignore-submodules --refresh
err=0

if ! git diff-files --quiet --ignore-submodules
then
	err=1
fi

if ! git diff-index --cached --quiet --ignore-submodules HEAD --
then
	err=1
fi

if [ $err = 1 ]
then
	exit 1
fi

