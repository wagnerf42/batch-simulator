#!/usr/bin/env perl
use strict;
use warnings;

use threads;
use threads::shared;
use Thread::Queue;
use Data::Dumper qw(Dumper);

use Trace;
use FCFS;
use FCFSC;
use Backfilling;
use Database;

my ($trace_file, $trace_size, $executions, $max_cpus, $threads) = @ARGV;
die 'missing arguments: tracefile jobs_number executions_number cpus_number threads_number' unless defined $threads;

my $database = Database->new();
my $git_status = system("./check_git.sh");
print "git $git_status\n";
die;

my %execution;
die;

# Create threads
print STDERR "Creating threads\n";
my @threads;
for my $i (0..($threads - 1)) {
	my $thread = threads->create(\&run_all_thread, $i);
	push @threads, $thread;
}

# Wait for all threads to finish
print STDERR "Waiting for all threads to finish\n";
my @results;
for my $i (0..($threads - 1)) {
	my $results_thread = $threads[$i]->join();
	print STDERR "Thread $i finished\n";

	push @results, @{$results_thread};
}

# Print all results in a file
print STDERR "Writing results\n";
write_results_to_file(\@results, "backfilling_FCFS-$trace_size-$executions-$max_cpus.csv");
exit;

sub write_results_to_file {
	my $results = shift;
	my $filename = shift;

	open(my $filehandle, "> $filename") or die "unable to open $filename";

	for my $results_item (@{$results}) {
		print $filehandle "$results_item->{contiguous}->{cmax} $results_item->{not_contiguous}->{cmax}\n";
	}

	close $filehandle;
}

sub run_all_thread {
	my $id = shift;
	my @results_all;

	my $trace = Trace->new_from_swf($trace_file);
	$trace->remove_large_jobs($max_cpus);

	for (1..($executions/$threads)) {
		my $trace_random = Trace->new_block_from_trace($trace, $trace_size);

		my $schedule_not_contiguous= FCFS->new($trace_random, $max_cpus);
		$schedule_not_contiguous->run();

		$trace_random->reset();

		my $schedule_contiguous = Backfilling->new($trace_random, $max_cpus, 1);
		$schedule_contiguous->run();

		my $results = {
			not_contiguous => {
				cmax => $schedule_not_contiguous->cmax,
				run_time => $schedule_not_contiguous->run_time
			},

			contiguous => {
				cmax => $schedule_contiguous->cmax,
				run_time => $schedule_contiguous->run_time
			}
		};

		push @results_all, $results;
	}

	return [@results_all];
}

