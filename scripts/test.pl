#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger);

use Trace;
use Backfilling;

my ($trace_file, $jobs_number, $cpus_number, $cluster_size) = @ARGV;
my @backfilling_variants = (BASIC);
#my @backfilling_variants = (BASIC, BEST_EFFORT_CONTIGUOUS, CONTIGUOUS, BEST_EFFORT_LOCAL, LOCAL);

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger();

$logger->info('reading trace');
my $trace = Trace->new_from_swf($trace_file);
$trace->remove_large_jobs($cpus_number/2);
$trace->reset_submit_times();

$logger->info('running scheduler');

for my $backfilling_variant (@backfilling_variants) {
	my $trace_random = Trace->new_from_trace($trace, $jobs_number);
	$trace_random->reset_jobs_numbers();
	$logger->info("running variant $backfilling_variant");
	my $schedule = Backfilling->new($trace_random, $cpus_number, $cluster_size, $backfilling_variant);
	$schedule->run();
	$schedule->tycat();
}

$logger->info('done');

