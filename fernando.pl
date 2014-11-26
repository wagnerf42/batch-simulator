#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Backfilling;
use ExecutionProfile ':stooges';

my ($trace_file_name, $processors_number) = @ARGV;
die unless defined $processors_number;

my $trace = Trace->new_from_swf($trace_file_name);
#$trace->remove_large_jobs($jobs_number);
#$trace->reset_submit_times();
print "$trace_file_name " . $trace->load($processors_number) . "\n";

#for my $job (@{$trace->{jobs}}) {
#	print join(' ', $job->{run_time}, $job->{allocated_cpus}) . "\n";
#}


