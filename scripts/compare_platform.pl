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

my $execution_id = 21;
my $required_cpus = 8;
my $threads_number = 6;

my $benchmark_class = 'B';
my $benchmarks_path = 'benchmarks';
my @included_benchmarks = ('cg', 'ft', 'lu', 'ep', 'mg');
my @benchmarks = map {"$_.$benchmark_class.$required_cpus"} (@included_benchmarks);

#my $benchmarks_path = 'collective';
#my @benchmarks =  ('osu_allreduce', 'osu_alltoallv', 'osu_scatter', 'osu_allgather', 'osu_gather', 'osu_reduce_scatter', 'osu_allgatherv', 'osu_barrier', 'osu_reduce', 'osu_bcast', 'osu_alltoall');

my $base_path = "experiment/combinations/combinations-$execution_id";
my $platform_file = "$base_path/platform.xml";
my $permutations_file = "$base_path/permutations";
my $results_file = "$base_path/compare_platform-$execution_id.csv";
#my $target_permutations_number = 10;

$logger->info("running execution id $execution_id, $required_cpus required cpus, $threads_number threads");

# Refuse to start if the results file already exists
$logger->logdie("results file already exists at $results_file") if -e $results_file;

my $results = [];
share($results);

open(my $file, '<', $permutations_file) or $logger->logdie("permutation file doesn't exist at $permutations_file");
my @permutations;
while (defined(my $permutation = <$file>)) {
	chomp($permutation);
	push @permutations, $permutation;
}

$logger->info("creating queue\n");
my $q = Thread::Queue->new();
$q->enqueue($_) for (0..$#permutations);
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
		my @permutation_parts = split('-', $permutations[$instance]);
		write_host_file(\@permutation_parts, $hosts_file_name);

		my $results_instance = [];
		share($results_instance);

		$logger->info("thread $id runing $instance");

		for my $benchmark_number (0..$#benchmarks) {
			my $result = `./smpireplay.sh $required_cpus $platform_file $hosts_file_name $benchmarks_path/$benchmarks[$benchmark_number]`;
			my ($simulation_time) = ($result =~ /Simulation time (\d*\.\d*)/);
			$results_instance->[$benchmark_number] = $simulation_time;
		}

		$results->[$instance] = $results_instance;
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
	return "log/compare_platform.log";
}

sub write_results {
	open(my $file, '>', $results_file);
	print $file "PERMUTATION " . join(' ' , @benchmarks) . "\n";

	for my $permutation_number (0..$#permutations) {
		my @results_temp = @{$results->[$permutation_number]}[0..$#benchmarks];
		my $position = $results->[$permutation_number]->[$#benchmarks + 1];
		print $file join(' ', $permutations[$permutation_number], @{$results->[$permutation_number]}) . "\n";
	}

	return;
}


