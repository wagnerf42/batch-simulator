#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Log::Log4perl qw(get_logger);

use Basic;
use BestEffortContiguous;
use ForcedContiguous;
use BestEffortLocal;
use ForcedLocal;
use BestEffortPlatform qw(SMALLEST_FIRST BIGGEST_FIRST);
use ForcedPlatform;

use Trace;
use Backfilling;

my ($jobs_number) = @ARGV;
die 'arguments' unless (defined $jobs_number);

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('experiment');

my $trace_file = '../swf/CEA-Curie-2011-2.1-cln-b1-clean2.swf';
#my $trace_file = '../swf2/test.swf';
#my @platform_levels = (1, 2, 4, 8, 16);
my @platform_levels = (1, 2, 64, 2048);
#my @platform_levels = (1, 2, 4, 8, 16);
my @platform_latencies = (2e-2, 1e-3, 1e-4);
#my @platform_speedup = (16, 8, 4, 1);

my $platform = Platform->new(\@platform_levels, \@platform_latencies);
$platform->generate_speedup('../NPB3.3.1/NPB3.3-MPI/bin/cg.B.2');
#$platform->set_speedup(\@platform_speedup);
#$platform->set_speedup(\@platform_latencies);

my $trace = Trace->new_from_swf($trace_file);
$trace->remove_large_jobs($platform->processors_number());
$trace->reset_jobs_numbers();
$trace->fix_submit_times();
$trace->keep_first_jobs($jobs_number);

my @variants = (
	Basic->new(),
	BestEffortContiguous->new(),
	ForcedContiguous->new(),
	BestEffortLocal->new($platform->cluster_size()),
	ForcedLocal->new($platform->cluster_size()),
	BestEffortPlatform->new($platform),
	ForcedPlatform->new($platform),
	BestEffortPlatform->new($platform, mode => SMALLEST_FIRST),
	ForcedPlatform->new($platform, mode => SMALLEST_FIRST),
	BestEffortPlatform->new($platform, mode => BIGGEST_FIRST),
	ForcedPlatform->new($platform, mode => BIGGEST_FIRST),
);

for my $variant_id (0..(@variants - 1)) {
	my $trace_copy = Trace->copy_from_trace($trace);

	my $schedule = Backfilling->new($variants[$variant_id], $platform, $trace_copy);
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
		$schedule->bounded_stretch(10),
		$schedule->job_success_rate(),
		$schedule->run_time(),
		$schedule->platform_level_factor(),
	);

	print STDOUT join(' ', @results) . "\n";
	$schedule->save_svg("/tmp/fernando/$variant_id.svg");
}

sub get_log_file {
	return "log/generate_platform.log";
}


