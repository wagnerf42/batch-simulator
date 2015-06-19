#!/bin/sh
CPUS=$1
HOSTFILE=$2
BENCHMARK=$3

smpirun -np $CPUS -platform platform.xml -hostfile $HOSTFILE \
	--cfg=smpi/privatize_global_variables:yes \
	--cfg=smpi/running_power:120Gf \
	--cfg=smpi/display_timing:1 \
	-trace-ti -trace-file $BENCHMARK.trace \
	$BENCHMARK
