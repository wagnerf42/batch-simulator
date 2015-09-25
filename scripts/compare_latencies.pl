#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Data::Dumper;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('compare_latencies');

my ($execution_id, $required_cpus) = @ARGV;

my $threads_number = 6;
my @benchmarks;
my @latencies = (1..40);

my $nasa_benchmark_class = 'B';
my $nasa_benchmarks_path = 'benchmarks';
my @nasa_included_benchmarks = ('cg', 'ft', 'lu');
push @benchmarks, map {"$nasa_benchmarks_path/$_.$nasa_benchmark_class.$required_cpus"} (@nasa_included_benchmarks);

my $new_benchmarks_path = 'new_benchmarks';
my @new_included_benchmarks = ('pairs', 'neighbour', 'circular');
#push @benchmarks, map {"$new_benchmarks_path/$_"} (@new_included_benchmarks);

my $collective_benchmarks_path = 'collective';
my @collective_included_benchmarks =  ('osu_allreduce', 'osu_alltoallv', 'osu_scatter', 'osu_allgather', 'osu_gather', 'osu_reduce_scatter', 'osu_allgatherv', 'osu_barrier', 'osu_reduce', 'osu_bcast', 'osu_alltoall');
#push @benchmarks, map {"$collective_benchmarks_path/$_"} (@collective_included_benchmarks);

my $mpi_benchmarks_path = 'mpi-benchmarks';
my @mpi_benchmarks_included_benchmarks = ('osu_bw');
#push @benchmarks, map {"$mpi_benchmarks_path/$_"} (@mpi_benchmarks_included_benchmarks);

my $base_path = "experiment/combinations/combinations-$execution_id";
my $platform_file = "$base_path/platform.xml";
my $tmp_platform_file = '/tmp/platform.xml';
my $permutations_file = "$base_path/permutations";
my $hosts_file = '/tmp/hosts';

$logger->info("running execution id $execution_id, $required_cpus required cpus");
$logger->info("running benchmarks: @benchmarks");

# Refuse to start if the directory or one of the files doesn't exist
$logger->logdie("experiment directory doesn't exist at $base_path") unless (-d $base_path);
$logger->logdie("platform file doesn't exist at $platform_file") unless (-e $platform_file);
$logger->logdie("permutations file doesn't exist at $permutations_file") unless (-e $permutations_file);

open(my $permutations_fd, '<', $permutations_file) or $logger->logdie("permutation file doesn't exist at $permutations_file");

while (defined(my $permutation = <$permutations_fd>)) {
	chomp($permutation);
	my @permutation_parts = split('-', $permutation);

	my $results_file = "$base_path/$permutation.csv";
	open(my $results_fd, '>', $results_file) or $logger->logdie("unable to create file $results_file");
	print $results_fd "LATENCY "  . join(' ', @benchmarks) . "\n";

	write_host_file(\@permutation_parts);

	for my $latency (@latencies) {
		my @latency_results;

		write_platform_file($latency);

		for my $benchmark (@benchmarks) {
			$logger->info("runing $permutation-$latency-$benchmark");

			$logger->debug("./scripts/smpi/smpireplay.sh $required_cpus $tmp_platform_file $hosts_file $benchmark");
			my $result = `./scripts/smpi/smpireplay.sh $required_cpus $tmp_platform_file $hosts_file $benchmark`;
			$logger->logdie("error running benchmark") unless ($result =~ /Simulation time (\d*\.\d*)/);

			push @latency_results, $1;
		}

		print $results_fd, "$latency " . join(' ', @latency_results);
	}
}

sub write_host_file {
	my $permutation = shift;

	open(my $fd, '>', $hosts_file);
	print $fd "$_\n" for (@{$permutation});
	return;
}

sub get_log_file {
	return "log/compare_latencies.log";
}

sub write_platform_file {
	my $latency = shift;
	my $result = `sed -e 's/EXTERNAL_LATENCY/$latency.0E-4/' $platform_file > $tmp_platform_file`;
}


