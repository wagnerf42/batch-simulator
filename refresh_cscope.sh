#!/bin/sh
INCLUDED_FILES="scripts/*.pl *.pm */*.pm"

ls $INCLUDED_FILES > cscope.files
cscope -b
export CSCOPE_DB="$PWD/cscope.db"

