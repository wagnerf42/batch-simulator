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

my ($trace_file, $jobs_number) = @ARGV;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger();

my @platform_levels = (1, 2, 4, 8);
my $cpus_number = $platform_levels[$#platform_levels];
my $trace = Trace->new_from_swf($trace_file);
$trace->remove_large_jobs($cpus_number);
#$trace->reset_jobs_numbers();
#$trace->fix_submit_times();
$trace->keep_first_jobs($jobs_number);

my $reduction_algorithm = ForcedPlatform->new(\@platform_levels, mode => SMALLEST_FIRST);

my $schedule = Backfilling->new($reduction_algorithm, $trace, $cpus_number);
$schedule->run();

my @results = (
	$schedule->cmax(),
	#$schedule->contiguous_jobs_number(),
	#$schedule->local_jobs_number(),
	#$schedule->locality_factor(),
	$schedule->stretch_sum_of_squares(),
	$schedule->stretch_with_cpus_squared(),
	$schedule->run_time(),
);

print STDOUT join(' ', @results) . "\n";
$schedule->tycat();

sub get_log_file {
	return 'log/run_schedule.log';
}
