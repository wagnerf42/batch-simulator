#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Time::HiRes qw(time);

# Runs several benchmarks using MPI

my ($cpus_number, $hosts_file, $permutations_file, $benchmark, $output_file) = @ARGV;

my $EXECUTIONS_NUMBER = 3;

unless (scalar @ARGV == 5) {
	print STDERR "usage: run.smpi.pl CPUS_NUMBER HOSTS_FILE PERMUTATIONS_FILE BENCHMARK OUTPUT_FILE\n";
	die;
}

my @hosts;
my @permutation_lines;

# Read the list of hosts and save it
open(my $hosts_fd, '<', $hosts_file) or die ('unable to open file');
while (my $host = <$hosts_fd>) {
	chomp $host;
	push @hosts, $host;
}
close($hosts_fd);

# Read the list of permutations
open(my $permutations_fd, '<', $permutations_file) or die ('unable to open file');
my $header_line = <$permutations_fd>;
chomp $header_line;

while (my $permutation_line = <$permutations_fd>) {
	chomp $permutation_line;
	push @permutation_lines, $permutation_line;
}

my @results = map {[]} (0..$#permutation_lines);

open(my $output_fd, '>', $output_file) or die ('unable to open file');

my @benchmark_name_parts = split('/', $benchmark);
print $output_fd "$header_line $benchmark_name_parts[-1]\n";

for my $execution (0..($EXECUTIONS_NUMBER - 1)) {
	for my $permutation_number (0..$#permutation_lines) {
		my @line_fields = split(' ', $permutation_lines[$permutation_number]);
		my $permutation = $line_fields[0];
		save_hosts_file($permutation, "/tmp/hosts-$permutation_number");
		my $start_time = time();

		my $result = `mpirun -np $cpus_number -hostfile /tmp/hosts-$permutation_number $benchmark &>/dev/null`;
		#print "mpirun -np $cpus_number -hostfile /tmp/hosts $benchmark &>/dev/null\n";

		my $execution_time = time() - $start_time;
		print "finished permutation $permutation execution $execution in $execution_time\n";
		push @{$results[$permutation_number]}, $execution_time;
	}
}

for my $permutation_number (0..$#permutation_lines) {
	print $output_fd "$permutation_lines[$permutation_number] @{$results[$permutation_number]}\n";
}

close($permutations_fd);
close($output_fd);

sub save_hosts_file {
	my $permutation = shift;
	my $output_file = shift;

	open (my $output_fd, '>', $output_file) or die ('unable to open file');

	my @cpus = split('-', $permutation);
	my @selected_hosts = map { $hosts[$_] } (@cpus);
	print $output_fd join("\n", @selected_hosts);
	close($output_fd);
}

