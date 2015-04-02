#!/bin/sh
INCLUDED_FILES=`find . -name '*.pm'`

ls $INCLUDED_FILES > cscope.files
cscope -b
export CSCOPE_DB="$PWD/cscope.db"

