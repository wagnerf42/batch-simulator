#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use threads;
use threads::shared;
use Thread::Queue;

use Trace;
use Backfilling;

my $trace_file = '../swf/CEA-Curie-2011-2.1-cln-b1-clean2.swf';
#my @jobs_numbers = (100, 200, 300, 400, 500);
#my @cpus_numbers = (10, 20, 30, 40, 50, 100);
my @jobs_numbers = (10, 20, 30, 40);
my @cpus_numbers = (10, 20, 30, 40);
my $cluster_size = 16;
my $threads_number = 4;
my $results_file_name = 'experiment/experiment_time1/experiment2.out';

my @results = (0) x (@jobs_numbers * @cpus_numbers);
share(@results);

print STDERR "Creating queue\n";
my $q = Thread::Queue->new();
for my $jobs_number_index (0..$#jobs_numbers) {
	for my $cpus_number_index (0..$#cpus_numbers) {
		$q->enqueue([$jobs_numbers[$jobs_number_index], $jobs_number_index, $cpus_numbers[$cpus_number_index], $cpus_number_index]);
	}
}
$q->end();

print STDERR "Creating threads\n";
my @threads = map {threads->create(\&run_instance, $_)} (0..($threads_number - 1));

print STDERR "Waiting for threads to finish\n";
$_->join() for (@threads);

print STDERR "Writing results to file\n";
write_results_to_file();

print STDERR "Done\n";
die;

sub run_instance {
	my $id = shift;

	while (defined(my $instance = $q->dequeue())) {
		my ($jobs_number, $jobs_number_index, $cpus_number, $cpus_number_index) = @$instance;

		my $trace = Trace->new_from_swf($trace_file);
		$trace->remove_large_jobs($cpus_number);
		$trace->keep_first_jobs($jobs_number);
		$trace->fix_submit_times();
		$trace->reset_jobs_numbers();

		my $schedule = Backfilling->new($trace, $cpus_number, $cluster_size, BASIC);
		$schedule->run();

		$results[$jobs_number_index * @cpus_numbers + $cpus_number_index] = $schedule->{schedule_time};
	}

	print STDERR "Thread $id finished\n";
	return;
}

sub write_results_to_file {
	open (my $file, '>', $results_file_name) or die "unable to open $results_file_name";

	for my $jobs_number_index (0..$#jobs_numbers) {
		for my $cpus_number_index (0..$#cpus_numbers) {
			print $file "$jobs_number_index $cpus_number_index $results[$jobs_number_index * @cpus_numbers + $cpus_number_index]\n";
		}
		print $file "\n";
	}

	close($file);
	return;
}


