#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Backfilling;
use ExecutionProfile ':stooges';
use Database;

my ($trace_file_name, $jobs_number, $executions_number, $cpus_number, $threads_number, $cluster_size) = @ARGV;

my $git_branch = `git symbolic-ref --short HEAD`;
chomp($git_branch);
my $git_tree_dirty = $git_branch eq 'master' and system('./check_git.sh');

# Create new execution in the database
my %execution = (
	trace_file => $trace_file_name,
	jobs_number => $jobs_number,
	executions_number => $executions_number,
	cpus_number => $cpus_number,
	threads_number => $threads_number,
	git_revision => `git rev-parse HEAD`,
	comments => "parser script, backfilling best effort vs local contiguous, blocks of jobs, without submit times",
	cluster_size => $cluster_size
);

my $database = Database->new();
$database->prepare_tables();
my $execution_id = $database->add_execution(\%execution);
print STDERR "Added execution $execution_id\n";

my $trace = Trace->new_from_swf($trace_file_name);

my $trace_random = Trace->new_from_trace($trace, 300);

my %trace_info = (
	trace_file => $trace_file_name,
	generation_method => "random_jobs",
	reset_submit_times => 0,
	fix_submit_times => 0,
	remove_large_jobs => 0
);

my $trace_id = $database->add_trace($trace_random, \%trace_info);
