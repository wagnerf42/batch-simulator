#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Data::Dumper;
use Time::HiRes qw(time);

# Runs several benchmarks using MPI

my ($cpus_number, $hosts_file, $permutations_file, $benchmark, $output_file) = @ARGV;

my @hosts;

# Read the list of hosts and save it
open(my $hosts_fd, '<', $hosts_file) or die ('unable to open file');
while (my $host = <$hosts_fd>) {
	chomp $host;
	push @hosts, $host;
}
close($hosts_fd);

# Generate the new hosts files based on the permutations
open(my $permutations_fd, '<', $permutations_file) or die ('unable to open file');
open(my $output_fd, '>', $output_file) or die ('unable to open file');

while (my $permutation = <$permutations_fd>) {
	chomp $permutation;

	save_hosts_file($permutation, "hosts");

	my $start_time = time();
	my $result = `mpirun -np $cpus_number -hostfile hosts $benchmark`;
	my $execution_time = time() - $start_time;
	print $output_fd "$permutation $execution_time\n";
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




