#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Time::HiRes qw(time);
use IO::Handle;
use File::Slurp;

# Runs several benchmarks using MPI

my ($job_path, $benchmarks_path) = @ARGV;

my $cpus_number = 16;
my $executions_number = 3;
my $hosts_file = "$job_path/hosts";
my $permutations_file = "$job_path/permutations";
my $output_file = "$job_path/run_mpi.csv";
my @benchmarks = ('cg.B', 'ft.B', 'lu.B');

# Read stuff
my @hosts = read_file($hosts_file, chomp => 1);
my @permutations = read_file($permutations_file, chomp => 1);

open(my $output_fd, '>', $output_file) or die ('unable to open output file');
$output_fd->autoflush(1);
print $output_fd "execution_number permutation permutation_number benchmark runtime\n";

for my $execution (0..($executions_number - 1)) {
	for my $permutation_number (0..$#permutations) {
		for my $benchmark (@benchmarks) {
			my $permutation = $permutations[$permutation_number];
			my $permutation_hosts_file = "$job_path/hosts-$permutation_number";
			save_hosts_file($permutation, $permutation_hosts_file);

			my $execution_time = run_benchmark("mpirun --mca btl_tcp_if_include br0 -np $cpus_number -hostfile $permutation_hosts_file $benchmarks_path/$benchmark.$cpus_number");
			print $output_fd "$execution $permutation $permutation_number $benchmark $execution_time\n";
		}
	}
}

close($output_fd);

sub save_hosts_file {
	my $permutation = shift;
	my $output_file = shift;

	my @cpus = split('-', $permutation);

	write_file($output_file, map { "$hosts[$_]\n" } (@cpus));
}

sub run_benchmark {
	my $command = shift;

	my $result = `$command`;

	unless ($result =~ /Time in seconds\s*=\s*(\d*\.\d*)/) {
		die("unable to retrieve execution time from command $command");
	}

	return $1;
}

