#!/bin/sh
CPUS=$1
HOSTFILE=$2
BENCHMARK=$3

smpirun -ext smpi_replay \
	--cfg=smpi/cpu_threshold:-1 \
	--cfg=smpi/privatize_global_variables:yes \
	--cfg=smpi/running_power:120Gf \
	--cfg=smpi/display_timing:1 \
	-np $CPUS -platform platform.xml -hostfile $HOSTFILE \
	./smpi_replay $BENCHMARK.trace \
	2>&1
