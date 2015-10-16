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

my $executions_number = 3;
my $cpus_number = 16;
my $hosts_file = "$job_path/hosts";
my $output_file = "$job_path/run_mpi_split.csv";
my @benchmarks = ('cg.C, ft.C, lu.B');

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
			my $execution_time = time();
			#TODO Think about saving the execution result into a log
			system "mpirun -np $cpus_number -hostfile $job_path/hosts-$split_position $benchmark_name";

			$execution_time = time() - $execution_time;
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

sub get_log_file {
	return "log/run_mpi_split.log";
}
