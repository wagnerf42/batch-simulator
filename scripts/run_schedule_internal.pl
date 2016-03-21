#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Log::Log4perl qw(get_logger);

use Trace;
use Backfilling;

use Basic;
use BestEffortContiguous;
use ForcedContiguous;
use BestEffortLocal;
use ForcedLocal;
use BestEffortPlatform qw(SMALLEST_FIRST BIGGEST_FIRST);
use ForcedPlatform;

use Debug;

my ($trace_file, $jobs_number, $variant_id, $platform_string, $platform_speedup_string, $execution_path) = @ARGV;

my $stretch_bound = 10;

Log::Log4perl::init('log4perl.conf');

my @platform_levels = split('-', $platform_string);
my @platform_speedup = split(',', $platform_speedup_string);

my $platform = Platform->new(\@platform_levels);
$platform->set_speedup(\@platform_speedup);

my $trace = Trace->new_from_swf($trace_file);
$trace->remove_large_jobs($platform->processors_number());
$trace->reset_jobs_numbers();
$trace->fix_submit_times();
$trace->keep_first_jobs($jobs_number);

my @variants = (
	Basic->new(),
	BestEffortContiguous->new(),
	ForcedContiguous->new(),
	BestEffortLocal->new($platform),
	ForcedLocal->new($platform),
	BestEffortPlatform->new($platform),
	ForcedPlatform->new($platform),
	BestEffortPlatform->new($platform, mode => SMALLEST_FIRST),
	ForcedPlatform->new($platform, mode => SMALLEST_FIRST),
	BestEffortPlatform->new($platform, mode => BIGGEST_FIRST),
	ForcedPlatform->new($platform, mode => BIGGEST_FIRST),
);

my $schedule = Backfilling->new($variants[$variant_id], $platform, $trace);
$schedule->run();

##DEBUG_BEGIN
#$schedule->save_svg("$execution_path/run_schedule_internal-$variant_id-$jobs_number.svg");
#$trace->write_to_file("$execution_path/run_schedule_internal-$variant_id-$jobs_number.swf");
##DEBUG_END

my @results = (
	$platform->processors_number(),
	$jobs_number,
	$platform->cluster_size(),
	#blessed $variants[$variant_id],
	$variant_id,
	$schedule->cmax(),
	$schedule->contiguous_jobs_number(),
	$schedule->local_jobs_number(),
	$schedule->locality_factor(),
	$schedule->bounded_stretch($stretch_bound),
	#$schedule->stretch_sum_of_squares($stretch_bound),
	#$schedule->stretch_with_cpus_squared($stretch_bound),
	$schedule->run_time(),
	$schedule->platform_level_factor(),
	$schedule->job_success_rate(),
);

print STDOUT join(' ', @results) . "\n";

sub get_log_file {
	return "$execution_path/run_schedule_internal.log";
}
