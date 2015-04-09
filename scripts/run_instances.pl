#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use threads;
use threads::shared;
use Thread::Queue;
use Log::Log4perl qw(get_logger);
use Time::HiRes qw(time);

use Trace;
use Backfilling;
use Database;

my $trace_file = '../swf/CEA-Curie-2011-2.1-cln-b1-clean2.swf';
my $instances = 60;
my $jobs_number = 300;
my $cpus_number = 512;
my $cluster_size = 16;
my $threads_number = 6;
my @backfilling_variants = (BASIC, BEST_EFFORT_CONTIGUOUS, CONTIGUOUS, BEST_EFFORT_LOCAL, LOCAL);

$SIG{INT} = \&catch_signal;

my $results = [];
share($results);

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('test_time');

$logger->info("Reading trace");
my $trace = Trace->new_from_swf($trace_file);
$trace->remove_large_jobs($cpus_number);
$trace->reset_submit_times();
$trace->reset_jobs_numbers();

my $database = Database->new();
$database->prepare_tables();

my %execution_info = (
	trace_file => $trace_file,
	jobs_number => $jobs_number,
	executions_number => $instances,
	cpus_number => $cpus_number,
	threads_number => $threads_number,
	git_revision => `git rev-parse HEAD`,
	comments => "",
	cluster_size => $cluster_size,
);

my $execution_id = $database->add_execution(\%execution_info);

$logger->info("Creating queue\n");
my $q = Thread::Queue->new();
$q->enqueue($_) for (0..($instances - 1));
$q->end();

my $run_time = time();

$logger->info("Creating threads");
my @threads = map {threads->create(\&run_instance, $_)} (0..($threads_number - 1));

$logger->info("Waiting for threads to finish");
while ((my $running_threads = threads->list()) > 0) {
	my @joinable_threads = threads->list(threads::joinable);
	$_->join() for (@joinable_threads);
	sleep(5);
}

$database->update_run_time($execution_info, time() - $run_time);

$logger->info("Writing results to file");
write_results_to_file();

$logger->info("Done");

sub run_instance {
	my $id = shift;
	my $logger = get_logger('test_time::run_instance');
	my $database = Database->new();

	# Exit the thread if a signal is received
	$SIG{INT} = sub { $logger->info("Killing thread $id"); threads->exit(); };

	while (defined(my $instance = $q->dequeue_nb())) {
		$logger->info("Thread $id running $instance");

		my $trace_instance = Trace->new_from_trace($trace, $jobs_number);
		my %trace_info = (
			generation_method => "random jobs",
			reset_submit_times => 1,
		);
		my $trace_id = $database->add_trace($trace_instance, \%trace_info);

		for my $backfilling_variant (@backfilling_variants) {
			my $schedule = Backfilling->new($trace_instance, $cpus_number, $cluster_size, $backfilling_variant);
			$schedule->run();

			my %instance_info = (
				algorithm => $backfilling_variant,
				cmax => $schedule->cmax(),
				contiguous_jobs => $schedule->contiguous_jobs_number(),
				local_jobs => $schedule->local_jobs_number(),
				locality_factor => $schedule->locality_factor(),
				run_time => $schedule->run_time(),
			);
			my $instance_id = $database->add_instance($execution_id, $trace_id, \%instance_info);
		}
	}

	$logger->info("Thread $id finished");
	return;
}

sub write_results_to_file {
	#open (my $file, '>', $results_file_name) or die "unable to open $results_file_name";
	#close($file);
	return;
}

sub write_results_to_database {


	return;
}

sub catch_signal {
	my $signame = shift;
	print STDERR "Received SIG$signame signal\n";
	$_->kill('INT')->detach() for @threads;
	return;
}


