#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger);

use Trace;
use Backfilling;

my ($trace_file, $jobs_number, $cpus_number) = @ARGV;
my $cluster_size = 16;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger();

$logger->info('reading trace');
my $trace = Trace->new_from_swf($trace_file);
$trace->remove_large_jobs($cpus_number);
$trace->reset_submit_times();

$logger->info('making new random trace');
my $trace_random = Trace->new_from_trace($trace, $jobs_number);
$trace_random->write_to_file("$jobs_number-$cpus_number.swf");

$logger->info('done');

