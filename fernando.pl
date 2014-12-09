#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use List::Util qw(max);

use Trace;
use Backfilling;
use ExecutionProfile ':stooges';
use Database;
use Util;

my ($trace_file_name, $cluster_size) = @ARGV;

my $trace = Trace->new_from_swf($trace_file_name);
$trace->fix_submit_times();
my $cpus_number = $trace->needed_cpus();
my $schedule = Backfilling->new($trace, $cpus_number, $cluster_size, EP_FIRST);
$schedule->run();

print STDERR "Done\n";

