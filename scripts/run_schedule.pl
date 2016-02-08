#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Log::Log4perl qw(get_logger);

use Trace;
use Backfilling;
use Basic;

my ($trace_file, $cpus_number, $jobs_number, $cluster_size, $variant) = @ARGV;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger();

my $trace = Trace->new_from_swf($trace_file);
$trace->remove_large_jobs($cpus_number);
$trace->reset_jobs_numbers();
$trace->fix_submit_times();
$trace->keep_first_jobs($jobs_number);

my $reduction_algorithm = Basic->new();

my $schedule = Backfilling->new($reduction_algorithm, $trace, $cpus_number);
$schedule->run();

my @results = (
	$schedule->cmax(),
	#$schedule->contiguous_jobs_number(),
	#$schedule->local_jobs_number(),
	#$schedule->locality_factor(),
	$schedule->run_time(),
);

print STDOUT join(' ', @results) . "\n";
$schedule->tycat();

sub get_log_file {
	return 'log/run_schedule.log';
}
