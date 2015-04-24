#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Log::Log4perl qw(get_logger);

use Trace;
use Backfilling;

my ($cluster_size, $backfilling_variant, $delay, $socket_file, $json_file) = @ARGV;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger();

my $schedule = Backfilling->new_simulation($cluster_size, $backfilling_variant, $delay, $socket_file, $json_file);
$schedule->run();

my @results = (
	$schedule->cmax(),
	$schedule->contiguous_jobs_number(),
	$schedule->local_jobs_number(),
	$schedule->locality_factor(),
	$schedule->run_time(),
);

print STDOUT join(' ', @results);
