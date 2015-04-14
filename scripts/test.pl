#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger);
use constant HAS_LEAKTRACE => eval{ require Test::LeakTrace };
use Test::More HAS_LEAKTRACE ? (tests => 1) : (skip_all => 'require Test::LeakTrace');
use Test::LeakTrace;

use Trace;
use Backfilling;

my ($trace_file, $jobs_number, $cpus_number, $cluster_size) = @ARGV;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger();

my $trace = Trace->new_from_swf($trace_file);
$trace->remove_large_jobs($cpus_number);
$trace->reset_submit_times();
$trace->keep_first_jobs($jobs_number);
$trace->reset_jobs_numbers();

leaks_cmp_ok {
	$logger->info('reading trace');


	$logger->info('running scheduler');
	for my $variant (BASIC, BEST_EFFORT_CONTIGUOUS, CONTIGUOUS, BEST_EFFORT_LOCAL, LOCAL) {
		$logger->info("running variant $variant");
		my $schedule = Backfilling->new($trace, $cpus_number, $cluster_size, $variant);
		$schedule->run();
		#$schedule->tycat();
		$trace->unassign_jobs();
	}
} '<', 1;

$logger->info('done');

