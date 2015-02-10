#!/usr/bin/env perl
use strict;
use warnings;

use threads;
use threads::shared;
use Thread::Queue;
use Data::Dumper qw(Dumper);
use File::Basename;
use List::Util qw(max sum);

use Trace;
use FCFS;
use FCFSC;
use Backfilling;
use Database;
use Random;
use ExecutionProfile ':stooges';
use Util;

local $| = 1;

my ($trace_file_name, $cluster_size) = @ARGV;
die 'parameters' unless defined $cluster_size;

my @variants = (
	EP_FIRST,
	EP_BEST_EFFORT,
	EP_CONTIGUOUS,
	EP_BEST_EFFORT_LOCALITY,
	EP_CLUSTER
);

my @variants_names = (
	"first",
	"becont",
	"cont",
	"beloc",
	"loc"
);

# Create new execution in the database
my %execution_info = (
	trace_file => $trace_file_name,
	script_name => "run_from_file_stretch.pl",
	executions_number => 1,
	threads_number => scalar @variants,
	git_revision => `git rev-parse HEAD`,
	git_tree_dirty => Util->git_tree_dirty(),
	comments => "trying to get some stretch data",
	cluster_size => $cluster_size
);

my $database = Database->new();
$database->prepare_tables();

my $execution_id = $database->add_execution(\%execution_info);
print STDERR "Started execution $execution_id\n";

# Create a directory to store the output
my $trace_base_name = get_trace_base_name($trace_file_name);
my $basic_file_name = "run_from_file_stretch-$trace_base_name-$cluster_size-$execution_id";
my $basic_dir = "experiment/run_from_file_stretch/$basic_file_name";
mkdir "$basic_dir";

# Main results array
my $results = [];
share($results);

print STDERR "Creating threads\n";
my $start_time = time();
my @threads = map { threads->create(\&run_all_thread, $_) } (0..$#variants);

# Wait for all threads to finish
$_->join() for (@threads);

# Update run time in the database
$database->update_execution_run_time($execution_id, time() - $start_time);

# save results on a file
print STDERR "Writing results to folder $basic_dir\n";
write_results_to_file($results);

sub run_all_thread {
	my ($id) = @_;

	my $database_thread = Database->new();

	my $trace = Trace->new_from_swf($trace_file_name);
	my %trace_info = (
		trace_file => $trace_file_name,
		generation_method => "file",
		reset_submit_times => 0,
		fix_submit_times => 0,
		remove_large_jobs => 0
	);
	my $trace_id = $database_thread->add_trace($trace, \%trace_info, 0);

	my $cpus_number = max map { $_->requested_cpus() } @{$trace->{jobs}};

	print STDERR "Running $id\n";

	my $schedule = Backfilling->new($trace, $cpus_number, $cluster_size, $variants[$id]);
	$schedule->run();

	my $results_thread = [];
	share($results_thread);
	push @{$results_thread}, map { $_->{wait_time} } (@{$schedule->{jobs}});

	my %instance_info = (
		algorithm => $variants_names[$id],
		run_time => $schedule->run_time(),
		cmax => $schedule->cmax()
	);
	my $instance_id = $database_thread->add_instance($execution_id, $trace_id, $results_thread, \%instance_info);

	$results->[$id] = $results_thread;

	print STDERR "Thread $id finished\n";
}

sub write_results_to_file {
	my ($results) = @_;

	for my $variant (0..$#variants) {
		open(my $filehandle, "> $basic_dir/$basic_file_name-$variants_names[$variant].csv") or die;
		print $filehandle join (' ', @{$results->[$variant]}) . "\n";
		close $filehandle;
	}
}

sub get_trace_base_name {
	my ($trace_file_name) = @_;
	my @trace_file_parts = split('-', fileparse($trace_file_name, qr/\.[^.]*/));
	return $trace_file_parts[0];
}
