#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Backfilling;
use ExecutionProfile ':stooges';
use Database;
use Util;

my ($trace_file_name, $jobs_number, $executions_number, $cpus_number, $threads_number, $cluster_size) = @ARGV;

my $database = Database->new();
$database->prepare_tables();

my %execution_info = (
	trace_file => $trace_file_name,
	script_name => "fernando.pl",
	jobs_number => $jobs_number,
	executions_number => $executions_number,
	cpus_number => $cpus_number,
	threads_number => $threads_number,
	git_revision => `git rev-parse HEAD`,
	git_tree_dirty => Util->git_tree_dirty(),
	comments => "",
	cluster_size => $cluster_size
);
my $execution_id = $database->add_execution(\%execution_info);

my $trace = Trace->new_from_swf($trace_file_name);
$trace->remove_large_jobs($cpus_number);
$trace->reset_submit_times();
my $trace_random = Trace->new_from_trace($trace, 300);

my %trace_info = (
	trace_file => $trace_file_name,
	generation_method => "random_jobs",
	reset_submit_times => 1,
	fix_submit_times => 0,
	remove_large_jobs => 1
);

my $trace_id = $database->add_trace($trace_random, \%trace_info);

my $schedule = Backfilling->new($trace_random, $cpus_number, $cluster_size, EP_FIRST);
my $start_time = time();
$schedule->run();

my %instance_info = (
	algorithm => "basic",
	run_time => time() - $start_time,
	cmax => $schedule->cmax()
);
my $instance_id = $database->add_instance($execution_id, $trace_id, \%instance_info);

my $results = [[10, 12, 14, 20], [1, 3, 4, 2, 1]];

#for my $job (@{$schedule->{jobs}}) {
#	push @{$results}, $job->cmax();
#}

$database->add_results($instance_id, $results);
