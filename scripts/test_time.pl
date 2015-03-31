#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use threads;
use threads::shared;
use Thread::Queue;
use Log::Log4perl qw(get_logger);

use Trace;
use Backfilling;

my $trace_file = '../swf/CEA-Curie-2011-2.1-cln-b1-clean2.swf';
my @jobs_numbers = (300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500);
my @cpus_numbers = (100);
my $cluster_size = 16;
my $threads_number = 2;
my $backfilling_variant = BASIC;
my $results_file_name = 'experiment/experiment_time4/dev';

$SIG{INT} = \&catch_signal;

my $results = [];
share($results);

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('test_time');
$logger->info("Creating queue\n");

my $q = Thread::Queue->new();
for my $jobs_number_index (0..$#jobs_numbers) {
	for my $cpus_number_index (0..$#cpus_numbers) {
		$q->enqueue([$jobs_numbers[$jobs_number_index], $jobs_number_index, $cpus_numbers[$cpus_number_index], $cpus_number_index]);
	}
}
$q->end();

$logger->info("Creating threads");
my @threads = map {threads->create(\&run_instance, $_)} (0..($threads_number - 1));

$logger->info("Waiting for threads to finish");
while ((my $running_threads = threads->list()) > 0) {
	my @joinable_threads = threads->list(threads::joinable);
	$_->join() for (@joinable_threads);
	sleep(5);
}

$logger->info("Writing results to file $results_file_name");
write_results_to_file();

$logger->info("Done");

sub run_instance {
	my $id = shift;
	my $logger = get_logger('test_time::run_instance');

	# Exit the thread if a signal is received
	$SIG{INT} = sub { $logger->info("Killing thread $id"); threads->exit(); };

	while (defined(my $instance = $q->dequeue_nb())) {
		my ($jobs_number, $jobs_number_index, $cpus_number, $cpus_number_index) = @$instance;

		$logger->info("Thread $id running ($jobs_number, $cpus_number)");

		my $trace = Trace->new_from_swf($trace_file);
		$trace->remove_large_jobs($cpus_number);
		$trace->keep_first_jobs($jobs_number);
		$trace->fix_submit_times();
		$trace->reset_jobs_numbers();

		my $schedule = Backfilling->new($trace, $cpus_number, $cluster_size, $backfilling_variant);
		$schedule->run();

		$results->[$jobs_number_index * @cpus_numbers + $cpus_number_index] = $schedule->{schedule_time};
	}

	$logger->info("Thread $id finished");
	return;
}

sub write_results_to_file {
	open (my $file, '>', $results_file_name) or die "unable to open $results_file_name";

	for my $jobs_number_index (0..$#jobs_numbers) {
		for my $cpus_number_index (0..$#cpus_numbers) {
			my $temp = $results->[$jobs_number_index * @cpus_numbers + $cpus_number_index];
			print $file "$jobs_numbers[$jobs_number_index] $cpus_numbers[$cpus_number_index] " . (defined $temp ? $temp : '?') . "\n";
		}
		print $file "\n";
	}

	close($file);
	return;
}

sub catch_signal {
	my $signame = shift;
	print STDERR "Received SIG$signame signal\n";
	$_->kill('INT')->detach() for @threads;
	return;
}


