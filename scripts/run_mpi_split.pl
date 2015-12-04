#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Time::HiRes qw(time);
use IO::Handle;
use File::Slurp;

# Runs several benchmarks using MPI

my ($job_path, $benchmark_path) = @ARGV;

my $executions_number = 5;
my $cpus_number = 16;
my $hosts_file = "$job_path/hosts";
my $output_file = "$job_path/run_mpi_split.csv";
my @benchmarks = ('cg.C', 'ft.C', 'lu.B');

# Read the list of hosts and save it
my @hosts = read_file($hosts_file, chomp => 1);

open(my $output_fd, '>', $output_file) or die ('unable to open output file');
$output_fd->autoflush(1);

print $output_fd "execution benchmark split_position execution_time\n";

save_hosts_file($_, "$job_path/hosts-$_") for (0..$cpus_number);

for my $execution (0..($executions_number - 1)) {
	for my $benchmark (@benchmarks) {
		my $benchmark_name = "$benchmark_path/$benchmark.$cpus_number";

		for my $split_position (0..$cpus_number) {
			my $execution_time = run_command("mpirun --mca btl_tcp_if_include br0 -np $cpus_number -hostfile $job_path/hosts-$split_position $benchmark_name");
			print $output_fd "$execution $benchmark $split_position $execution_time\n";
		}
	}
}

close($output_fd);

sub save_hosts_file {
	my $split_position = shift;
	my $output_file = shift;

	my @cpus = (0..($cpus_number - 1));

	unlink($output_file);
	write_file($output_file, {append => 1}, map { "$hosts[$_]\n" } (@cpus[0..($split_position - 1)])) if ($split_position > 0);
	write_file($output_file, {append => 1}, map { "$hosts[$cpus_number + $_]\n" } (@cpus[$split_position..$#cpus])) if ($split_position < 16);
}

sub run_command {
	my $command = shift;

	my $result = `$command`;
	die("unable to retrieve execution time from command $command") unless ($result =~ /Time in seconds\s*=\s*(\d*\.\d*)/);
	return $1;
}
