#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Data::Dumper;
use threads;
use threads::shared;
use Thread::Queue;
use File::Slurp;

# Script that runs simulations for all the possible ways to split two clusters
# of CPUs. 

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('run_smpi_split');

my ($experiment_number, $benchmark) = @ARGV;

my $threads_number = 6;
my $experiment_path = "experiment/combinations/combinations-$experiment_number";
my $hosts_file = "$experiment_path/hosts";
my $platform_file = "$experiment_path/platform.xml";
my $results_file = "$experiment_path/run_smpi_split.csv";

my @benchmarks;

$logger->info("running with arguments @ARGV\n");

# Refuse to start if the results file already exists
#$logger->logdie("results file already exists at $results_file") if (-e $results_file);

my @hosts = read_file($hosts_file, chomp => 1);
my $cpus_number = @hosts/2;

my $results = [];
share($results);

my $q = Thread::Queue->new();
$q->enqueue($_) for (0..$cpus_number);
$q->end();

my @threads = map { threads->create(\&run_instance, $_) } (0..($threads_number - 1));

$logger->debug("waiting for threads to finish");
$_->join() for (@threads);


write_file($results_file, "split_position simulated_time\n" . join("\n", map { "$_ $results->[$_]" } (0..$cpus_number)));

sub run_instance {
	my $id = shift;

	my $logger = get_logger('compare_platform::run_instance');

	while (defined(my $instance = $q->dequeue_nb())) {
		my $hosts_file_instance = "$experiment_path/hosts-$instance";
		save_hosts_file($instance, $hosts_file_instance);

		$logger->info("thread $id running $instance");

		my $result = `./scripts/smpi/smpireplay.sh $cpus_number $platform_file $hosts_file_instance $benchmark`;
		write_file("$experiment_path/run_smpi_split-$instance.log", $result);

		unless ($result =~ /Simulation time (\d*\.\d*)/) {
			$logger->debug("command: ./scripts/smpi/smpireplay.sh $cpus_number $platform_file $hosts_file_instance $benchmark\n");
			$logger->logdie("error running the replay");
		}

		$results->[$instance] = $1;
	}

	return;
}

sub save_hosts_file {
	my $split_position = shift;
	my $output_file = shift;

	my @cpus = map { $_ } (0..($cpus_number - 1));

	unlink($output_file);
	write_file($output_file, {append => 1}, map { "$hosts[$_]\n" } (@cpus[0..($split_position - 1)])) if ($split_position > 0);
	write_file($output_file, {append => 1}, map { "$hosts[$cpus_number + $_]\n" } (@cpus[$split_position..$#cpus])) if ($split_position < 16);
}

sub get_log_file {
	return "log/run_smpi_split.log";
}

