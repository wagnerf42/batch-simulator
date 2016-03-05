#!/bin/sh
parallel inkscape --export-pdf={.}.pdf {} ::: *.svg
