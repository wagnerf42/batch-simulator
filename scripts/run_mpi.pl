#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Time::HiRes qw(time);
use IO::Handle;
use File::Slurp;

# Runs several benchmarks using MPI

my ($cpus_number, $hosts_file, $permutations_file, $benchmark, $output_file) = @ARGV;

my $executions_number = 3;

# Read the list of hosts and save it
my @hosts = read_file($hosts_file, chomp => 1);

# Read the list of permutations
my @permutations = read_file($permutations_file, chomp => 1);

open(my $output_fd, '>', $output_file) or die ('unable to open output file');
$output_fd->autoflush(1);
print $output_fd "permutation permutation_number execution_number runtime\n";

for my $execution (0..($executions_number - 1)) {
	for my $permutation_number (0..$#permutations) {
		my $permutation = $permutations[$permutation_number];
		save_hosts_file($permutation, "/tmp/hosts-$permutation_number");

		my $execution_time = time();
		system "mpirun -np $cpus_number -hostfile /tmp/hosts-$permutation_number $benchmark";
		$execution_time = time() - $execution_time;

		print $output_fd "$permutation $permutation_number $execution $execution_time\n";
	}
}

close($output_fd);


sub save_hosts_file {
	my $permutation = shift;
	my $output_file = shift;

	my @cpus = split('-', $permutation);

	write_file($output_file, map { "$hosts[$_]\n" } (@cpus));
}

