#!/bin/sh
CPUS=$1
PLATFORMFILE=$2
HOSTFILE=$3
BENCHMARK=$4

# Generates a trace to be used with Viva

smpirun -np $CPUS -platform $PLATFORMFILE -hostfile $HOSTFILE \
	--cfg=tracing:yes \
	--cfg=tracing/uncategorized:yes \
	--cfg=smpi/privatize_global_variables:yes \
	--cfg=smpi/running_power:120Gf \
	--cfg=smpi/display_timing:yes \
	--cfg=viva/uncategorized:$BENCHMARK-$CPUS.plist \
	--cfg=tracing/filename:$BENCHMARK-$CPUS.vtrace \
	$BENCHMARK 2>&1
