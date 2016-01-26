#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Log::Log4perl qw(get_logger);

use Trace;
use Backfilling;

my ($execution_id) = @ARGV;

my $trace_file = '../swf/CEA-Curie-2011-2.1-cln-b1-clean2.swf';
my @variants = (BASIC, BEST_EFFORT_CONTIGUOUS, CONTIGUOUS, BEST_EFFORT_LOCAL, LOCAL);
my @jobs_numbers = (10);
my $experiment_path = 'experiment/run_schedule_platform';

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('experiment');

my $results = [];
share($results);

my $basic_file_name = "run_schedule_platform-$variant-$jobs_number-$execution_id";
my $experiment_folder ="$experiment_path/$basic_file_name";

#my $cpus_number = $trace->needed_cpus();
my @platform_levels_parts = split('-', $levels);
my $cpus_number = $platform_levels_parts[$#platform_levels_parts];
my $cluster_size = $platform_levels_parts[$#platform_levels_parts]/$platform_levels_parts[$#platform_levels_parts - 1];

my $schedule = Backfilling->new($trace, $cpus_number, $cluster_size, $variant, \@platform_levels_parts);
$schedule->run();

my @results = (
	$variant,
	$jobs_number,
	$schedule->cmax(),
	$schedule->contiguous_jobs_number(),
	$schedule->local_jobs_number(),
	$schedule->locality_factor(),
	$schedule->bounded_stretch(),
	$schedule->run_time(),
);

print STDOUT join(' ', (
	'VARIANT',
	'JOBS_NUMBER',
	'CMAX',
	'CONT_JOBS',
	'LOC_JOBS',
	'LOC_FACTOR',
	'BOUNDED_STRETCH',
	'RUN_TIME',
)) . "\n";

print STDOUT join(' ', @results) . "\n";
#$schedule->tycat();

sub get_log_file {
	return "log/generate_platform.log";
}

