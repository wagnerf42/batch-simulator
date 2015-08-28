#!/bin/sh
CPUS=$1
PLATFORMFILE=$2
HOSTFILE=$3
BENCHMARK=$4

smpirun -np $CPUS -platform $PLATFORMFILE -hostfile $HOSTFILE \
	--cfg=smpi/privatize_global_variables:yes \
	--cfg=smpi/running_power:120Gf \
	--cfg=smpi/display_timing:1 \
	-trace-ti -trace-file $BENCHMARK-$CPUS.trace \
	$BENCHMARK
