#!/bin/sh
CPUS=$1
PLATFORMFILE=$2
HOSTFILE=$3
BENCHMARK=$4

smpirun -ext smpi_replay \
	--cfg=smpi/cpu_threshold:-1 \
	--cfg=smpi/privatize_global_variables:yes \
	--cfg=smpi/running_power:120Gf \
	--cfg=smpi/display_timing:1 \
	-np $CPUS -platform $PLATFORMFILE -hostfile $HOSTFILE \
	-trace -trace-file $BENCHMARK-$CPUS.pj \
	./smpi_replay $BENCHMARK-$CPUS.trace \
	2>&1
