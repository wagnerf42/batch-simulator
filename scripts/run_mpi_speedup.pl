#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Time::HiRes qw(time);
use IO::Handle;
use File::Slurp;

# Runs several benchmarks using MPI

my ($job_path, $benchmarks_folder) = @ARGV;

my $executions_number = 3;
my @cpus_numbers = (16, 32, 64);
my $hosts_file = "$job_path/hosts";
my $output_file = "$job_path/run_mpi_speedup.csv";
my @benchmarks = ('cg.C', 'ft.C', 'lu.B');

# Read the list of hosts and save it
my @hosts = read_file($hosts_file, chomp => 1);

open(my $output_fd, '>', $output_file) or die ('unable to open output file');
$output_fd->autoflush(1);

print $output_fd "execution_number benchmark cpus_number runtime\n";

for my $execution (0..($executions_number - 1)) {
	for my $cpus_number (@cpus_numbers) {
		for my $benchmark (@benchmarks) {
			my $benchmark_name = "$benchmarks_folder/$bencmark.$cpus_number";

			my $execution_time = time();
			system "mpirun -np $cpus_number -hostfile $hosts_file $benchmark";
			$execution_time = time() - $execution_time;

			print $output_fd "$execution $bnechmark $cpus_number $execution_time\n";
		}
	}
}

close($output_fd);

