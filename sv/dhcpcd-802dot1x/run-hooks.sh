#!/bin/sh
for hook in \
	"$(CDPATH='' cd --  "$(dirname -- "$0")" && pwd)"/hooks/*
do
	if [ -f "$hook" ]; then
		. "$hook"
	fi
done
