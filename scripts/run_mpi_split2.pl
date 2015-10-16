#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Data::Dumper;
use Time::HiRes qw(time);
use IO::Handle;
use File::Slurp;

# Runs several benchmarks using MPI

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('run_mpi_split');

my ($job_path, $benchmark_path) = @ARGV;

my $executions_number = 7;
my $cpus_number = 16;
my $hosts_file = "$job_path/hosts";
my $output_file = "$job_path/run_mpi_split2.csv";
my @benchmarks = ('cg.C', 'ft.C', 'lu.B');

# Read the list of hosts and save it
my @hosts = read_file($hosts_file, chomp => 1);

open(my $output_fd, '>', $output_file) or die ('unable to open output file');
$output_fd->autoflush(1);

print $output_fd "execution benchmark cpus_number split_position execution_time\n";

for my $execution (0..($executions_number - 1)) {
	for my $benchmark (@benchmarks) {
		my $benchmark_name = "$benchmark_path/$benchmark." . $cpus_number/2;
		my $execution_time = run_command("mpirun --mca btl_tcp_if_include br0 -np " . $cpus_number/2 . " -hostfile $job_path/hosts-8a $benchmark_name");
		print $output_fd "$execution $benchmark " . $cpus_number/2 . " 0 $execution_time\n";

		$execution_time = run_command("mpirun --mca btl_tcp_if_include br0 -np " . $cpus_number/2 . " -hostfile $job_path/hosts-8b $benchmark_name");
		print $output_fd "$execution $benchmark " . $cpus_number/2 . " 8 $execution_time\n";

		$benchmark_name = "$benchmark_path/$benchmark.$cpus_number";
		$execution_time = run_command("mpirun --mca btl_tcp_if_include br0 -np $cpus_number -hostfile $job_path/hosts-16 $benchmark_name");
		print $output_fd "$execution $benchmark $cpus_number 8 $execution_time\n";
	}
}

close($output_fd);

sub get_log_file {
	return "log/run_mpi_split.log";
}

sub run_command {
	my $command = shift;

	my $start_time = time();
	system $command;

	return time() - $start_time;
}
