#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Data::Dumper;
use threads;
use Thread::Queue;
use threads::shared;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('compare_platform');

my ($required_cpus, $platform_file, $permutations_file, $benchmark, $results_file) = @ARGV;

my $threads_number = 6;

my @benchmarks;

$logger->info("running with arguments @ARGV\n");

# Refuse to start if the results file already exists
$logger->logdie("results file already exists at $results_file") if (-e $results_file);

my $results = [];
share($results);

open(my $file, '<', $permutations_file) or $logger->logdie("permutation file doesn't exist at $permutations_file");
my $header = <$file>;
chomp($header);
my @header_fields = split(' ', $header);
$logger->logdie("permutation file with wrong format") unless ($header_fields[0] eq "PERMUTATION");

my @rows;
my $q = Thread::Queue->new();

while (defined(my $row = <$file>)) {
	chomp($row);
	my @row_parts = split(' ', $row);

	push @rows, [@row_parts];
	$q->enqueue($#rows);
}

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
		write_host_file($rows[$instance]->[0], $hosts_file_name);

		my $results_instance = [];
		share($results_instance);

		$logger->info("thread $id runing $instance");
		$logger->debug("./scripts/smpi/smpireplay.sh $required_cpus $platform_file $hosts_file_name $benchmark\n");

		my $result = `./scripts/smpi/smpireplay.sh $required_cpus $platform_file $hosts_file_name $benchmark`;
		$logger->logdie("error running the replay") unless ($result =~ /Simulation time (\d*\.\d*)/);

		$results->[$instance] = $1;
	}

	unlink($hosts_file_name);
	return;
}

sub write_host_file {
	my $hosts_list = shift;
	my $file_name = shift;

	my @hosts = split('-', $hosts_list);

	open(my $file, '>', $file_name);

	print $file "$_\n" for (@hosts);
	return;
}

sub get_log_file {
	return "log/compare_platform2.log";
}

sub write_results {
	open(my $file, '>', $results_file);
	print $file "$header $benchmark\n";

	for my $permutation_number (0..$#rows) {
		print $file "@{$rows[$permutation_number]} $results->[$permutation_number]\n";
	}

	return;
}


