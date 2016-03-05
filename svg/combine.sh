#!/bin/sh
rm output.pdf
gs -dQUIET -dSAFER -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOUTPUTFILE=output.pdf -f `ls *.pdf | sort -n`
