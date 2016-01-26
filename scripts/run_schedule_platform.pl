#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Log::Log4perl qw(get_logger);

use Trace;
use Backfilling;

my ($trace_file, $variant, $levels, $jobs_number) = @ARGV;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger();

my $trace = Trace->new_from_swf($trace_file);
$trace->keep_first_jobs($jobs_number);

my $cpus_number = $trace->needed_cpus();
my @platform_levels_parts = split('-', $levels);
my $cpus_number = $platform_levels_parts[$#platform_levels_parts];
my $cluster_size = $platform_levels_parts[$#platform_levels_parts]/$platform_levels_parts[$#platform_levels_parts - 1];

$logger->info("using trace file: $trace_file");
$logger->info("using platform levels: $levels");
$logger->info("using cpus number: $cpus_number");
$logger->info("using cluster size: $cluster_size");

my $schedule = Backfilling->new($trace, $cpus_number, $cluster_size, $variant, \@platform_levels_parts);
$schedule->run();

my @results = (
	$schedule->cmax(),
	$schedule->contiguous_jobs_number(),
	$schedule->local_jobs_number(),
	$schedule->locality_factor(),
	$schedule->run_time(),
);

print STDOUT join(' ', @results) . "\n";
#$schedule->tycat();

