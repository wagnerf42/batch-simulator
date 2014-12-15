#!/bin/sh
INCLUDED_FILES="*.pl *.pm"

ls $INCLUDED_FILES > cscope.files
cscope -b
export CSCOPE_DB="$PWD/cscope.db"

