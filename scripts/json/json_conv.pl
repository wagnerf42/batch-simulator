#!/usr/bin/env perl
use strict;
use warnings;
use Trace;

die "give file and cpus and number of jobs" unless @ARGV and -f $ARGV[0];
die "give file and cpus and number of jobs" unless $ARGV[1] =~ /\d+/;
die "give file and cpus and number of jobs" unless $ARGV[2] =~ /\d+/;

my $trace = Trace->new_from_swf($ARGV[0]);
my $cpu_number = $ARGV[1];
$trace->remove_large_jobs($cpu_number);

my $generated_trace = Trace->new_from_trace($trace, $ARGV[2]);
$generated_trace->reset_submit_times();

my $output_file = "test.json";
$generated_trace->save_json($cpu_number, $output_file);
