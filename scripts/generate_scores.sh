#!/bin/sh
SCRIPTS_DIR="$PWD/scripts"
COST_FILE="$PWD/cost/cost-8-2"
CPUS_NUMBER="8"
LOGS_DIR="$PWD/benchmark_logs"
SEND_LOGS_DIR="$PWD/send_logs"
COMM_DIR="$PWD/communication"
SCORES_DIR="$PWD/score"
PERMUTATIONS_FILE="/home/fernando/Documents/batch-simulator/experiment/combinations/combinations-42/permutations"

INPUT_FILE=$1

base_name=`basename $INPUT_FILE .log`
send_name="$SEND_LOGS_DIR/$base_name-send.log"
comm_name="$COMM_DIR/$base_name.comm"
score_name="$SCORES_DIR/$base_name.csv"

grep smpi_mpi_send $INPUT_FILE > $send_name
$SCRIPTS_DIR/read_comm.pl $send_name $CPUS_NUMBER > $comm_name
$SCRIPTS_DIR/permutation_latency.pl $comm_name $COST_FILE $PERMUTATIONS_FILE > $score_name

