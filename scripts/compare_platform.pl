#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Data::Dumper;
use threads;
use Thread::Queue;
use threads::shared;

use Platform;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('test');

my @benchmarks = ('benchmarks/cg.B.8', 'benchmarks/ft.B.8', 'benchmarks/lu.B.8');
my $execution_id = 1;
my $required_cpus = 8;
my $threads_number = 6;
my $permutations_file_name = '/tmp/permutations';
my $target_permutations_number = 10;

my $results = [];
share($results);

open(my $file, '<', $permutations_file_name);
my @permutations;
while (defined(my $permutation = <$file>)) {
	chomp($permutation);
	push @permutations, $permutation;
}

$logger->info("creating queue\n");
my $q = Thread::Queue->new();
$q->enqueue([$_, int rand($#permutations)]) for (0..($target_permutations_number - 1));
$q->end();

$logger->info("creating threads");
my @threads = map { threads->create(\&run_instance, $_) } (0..($threads_number - 1));

$logger->debug("waiting for threads to finish");
$_->join() for (@threads);

write_results();

sub run_instance {
	my $id = shift;

	my $hosts_file_name = "/tmp/hosts-$id";
	my $logger = get_logger('compare_platform::run_instance');

	while (defined(my $instance = $q->dequeue_nb())) {
		my ($instance_number, $position) = @{$instance};
		my @permutation_parts = split('-', $permutations[$position]);
		write_host_file(\@permutation_parts, $hosts_file_name);

		my $results_instance = [];
		share($results_instance);

		$logger->info("thread $id runing $instance_number");

		for my $benchmark_number (0..$#benchmarks) {
			my $result = `./smpireplay.sh $required_cpus $hosts_file_name $benchmarks[$benchmark_number]`;
			my ($simulation_time) = ($result =~ /Simulation time (\d*\.\d*)/);
			$results_instance->[$benchmark_number] = $simulation_time;
		}

		$results_instance->[$#benchmarks + 1] = $position;
		$results->[$instance_number] = $results_instance;
	}

	unlink($hosts_file_name);
	return;
}

sub write_host_file {
	my $permutation = shift;
	my $file_name = shift;

	open(my $file, '>', $file_name);

	print $file "$_\n" for (@{$permutation});
	return;
}

sub get_log_file {
	return "compare_platform.log";
}

sub write_results {
	open(my $file, '>', "compare_platform-$execution_id.csv");
	print $file "PERMUTATION " . join(' ' , @benchmarks) . "\n";

	for my $permutation_number (0..($target_permutations_number - 1)) {
		my @results_temp = @{$results->[$permutation_number]}[0..$#benchmarks];
		my $position = $results->[$permutation_number]->[$#benchmarks + 1];
		print $file join(' ', $permutations[$position], @results_temp) . "\n";
	}

	return;
}


