#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Log::Log4perl qw(get_logger);

use Trace;
use Backfilling;

my (
	$json_file,
	$cpus_number,
	$cluster_size,
	$variant,
	$platform_levels,
	$delay,
	$socket_file,
) = @ARGV;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('experiment');

my @platform_levels_parts = split('-', $platform_levels);

my $schedule = Backfilling->new_simulation($cluster_size, $variant, $delay, $socket_file, $json_file, \@platform_levels_parts);
$schedule->run();

my @results = (
	$cpus_number,
	$cluster_size,
	$variant,
	$schedule->cmax(),
	$schedule->contiguous_jobs_number(),
	$schedule->local_jobs_number(),
	$schedule->locality_factor(),
	$schedule->bounded_stretch(10),
	$schedule->run_time(),
);

print STDOUT join(' ', @results) . "\n";
#$schedule->tycat();

sub get_log_file {
	return "log/generate_platform.log";
}


