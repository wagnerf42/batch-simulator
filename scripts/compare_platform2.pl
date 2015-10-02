#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Data::Dumper;
use threads;
use threads::shared;
use Thread::Queue;
use File::Slurp;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('compare_platform');

my ($required_cpus, $platform_file, $hosts_file, $permutations_file, $benchmark, $results_file) = @ARGV;

unless (@ARGV == 6) {
	$logger->logdie('usage: $required_cpus, $platform_file, $hosts_file, $permutations_file, $benchmark, $results_file');
}

my $threads_number = 6;
my @benchmarks;

$logger->info("running with arguments @ARGV\n");

# Refuse to start if the results file already exists
$logger->logdie("results file already exists at $results_file") if (-e $results_file);

my $results = [];
share($results);

my @hosts = read_file($hosts_file, chomp => 1);
my @permutation_lines = read_file($permutations_file, chomp => 1);
my $header = shift(@permutation_lines);

my $q = Thread::Queue->new();
$q->enqueue($_) for (0..$#permutation_lines);
$q->end();

my @threads = map { threads->create(\&run_instance, $_) } (0..($threads_number - 1));

$logger->debug("waiting for threads to finish");
$_->join() for (@threads);

write_results();

sub run_instance {
	my $id = shift;

	my $hosts_file_name = "/tmp/hosts-$id";
	my $logger = get_logger('compare_platform::run_instance');

	while (defined(my $instance = $q->dequeue_nb())) {
		write_host_file($instance, $hosts_file_name);

		$logger->info("thread $id runing $instance");

		my $result = `./scripts/smpi/smpireplay.sh $required_cpus $platform_file $hosts_file_name $benchmark`;

		unless ($result =~ /Simulation time (\d*\.\d*)/) {
			$logger->debug("command: ./scripts/smpi/smpireplay.sh $required_cpus $platform_file $hosts_file_name $benchmark\n");
			$logger->logdie("error running the replay");
		}

		$results->[$instance] = $1;
	}

	unlink($hosts_file_name);
	return;
}

sub write_host_file {
	my $instance = shift;
	my $file_name = shift;

	my $permutation_line = $permutation_lines[$instance];
	my @permutation_line_parts = split(' ', $permutation_line);
	my @permutation_parts = split('-', $permutation_line_parts[0]);

	write_file($file_name, map { "$hosts[$_]\n" } (@permutation_parts));
	return;
}

sub get_log_file {
	return "log/compare_platform2.log";
}

sub write_results {
	write_file($results_file, join("\n",
			"$header stime",
			map { join(' ', $permutation_lines[$_], $results->[$_]) } (0..$#permutation_lines)
		)
	);

	return;
}


