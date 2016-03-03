#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Log::Log4perl qw(get_logger);

use Trace;
use Backfilling;
use Basic;
use BestEffortPlatform;
use BestEffortContiguous;
use ForcedPlatform;

my ($jobs_number) = @ARGV;
die 'arguments' unless (defined $jobs_number);

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('experiment');

#my $trace_file = '../swf/CEA-Curie-2011-2.1-cln-b1-clean2.swf';
my $trace_file = '../swf2/test.swf';
#my @platform_levels = (1, 2, 4, 8, 16);
#my @platform_levels = (1, 2, 40, 5040, 80640);
my @platform_levels = (1, 2, 4, 8, 16);
my @platform_latencies = (1e-1, 1e-2, 1e-3, 1e-4);
my @platform_speedup = (16, 8, 4, 1);

my $platform = Platform->new(\@platform_levels, \@platform_latencies);
my $reduction_algorithm = ForcedPlatform->new($platform);
#$platform->generate_speedup('../NPB3.3.1/NPB3.3-MPI/bin/cg.B.2');
$platform->set_speedup(\@platform_speedup);

my $trace = Trace->new_from_trace(Trace->new_from_swf($trace_file), $jobs_number);
$trace->reset_jobs_numbers();
$trace->fix_submit_times();
$trace->remove_large_jobs($platform->processors_number());
#$trace->keep_first_jobs($jobs_number);

my $schedule = Backfilling->new($reduction_algorithm, $platform, $trace);
$schedule->run();

my @results = (
	#$cpus_number,
	#$jobs_number,
	#$cluster_size,
	#$variant,
	$schedule->cmax(),
	#$schedule->contiguous_jobs_number(),
	#$schedule->local_jobs_number(),
	#$schedule->locality_factor(),
	#$schedule->bounded_stretch(10),
	$schedule->job_success_rate(),
	$schedule->run_time(),
	$schedule->platform_level_factor(),
);

print STDOUT join(' ', @results) . "\n";
$schedule->tycat();

sub get_log_file {
	return "log/generate_platform.log";
}


