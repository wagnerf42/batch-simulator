#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Time::HiRes qw(time);
use IO::Handle;
use File::Slurp;

# Runs several benchmarks using MPI

my ($hosts_file, $benchmark, $output_file) = @ARGV;

my $executions_number = 3;
my $cluster_size = 8;
my $cpus_number = 16;
my $permutation = '0-1-2-3-4-5-6-7-8-9-10-11-12-13-14-15';

# Read the list of hosts and save it
my @hosts = read_file($hosts_file, chomp => 1);

open(my $output_fd, '>', $output_file) or die ('unable to open output file');
$output_fd->autoflush(1);

print $output_fd "permutation permutation_number split_position execution_number runtime\n";

for my $execution (0..($executions_number - 1)) {
	for my $split_position (0..$cpus_number) {
		my $host_file = "/tmp/hosts-$split_position";
		save_hosts_file($split_position, $host_file);

		my $execution_time = time();
		#TODO Think about saving the execution result into a log
		system "mpirun -np $cpus_number -hostfile $host_file $benchmark";
		$execution_time = time() - $execution_time;

		print $output_fd "$permutation 0 $split_position $execution $execution_time\n";
	}
}

close($output_fd);


sub save_hosts_file {
	my $split_position = shift;
	my $output_file = shift;

	my @cpus = split('-', $permutation);

	unlink($output_file);
	write_file($output_file, {append => 1}, map { "$hosts[$_]\n" } (@cpus[0..($split_position - 1)])) if ($split_position > 0);
	write_file($output_file, {append => 1}, map { "$hosts[$cpus_number + $_]\n" } (@cpus[$split_position..$#cpus])) if ($split_position < 16);
}

