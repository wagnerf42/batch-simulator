#!/usr/bin/env perl
use strict;
use warnings;

use threads;
use threads::shared;
use Thread::Queue;

use Data::Dumper qw(Dumper);
use Log::Log4perl qw(get_logger);

use Trace;
use Backfilling;

my ($execution_id) = @ARGV;

my $trace_file = '../swf/CEA-Curie-2011-2.1-cln-b1-clean2.swf';
my @variants = (
	BASIC,
	BEST_EFFORT_CONTIGUOUS,
	CONTIGUOUS,
	BEST_EFFORT_LOCAL,
	LOCAL,
	BEST_EFFORT_PLATFORM,
	PLATFORM
);

my @jobs_numbers = (400, 800, 1200, 1600, 2000);
my $experiment_path = 'experiment/run_instances_platform';
my $threads_number = 6;
my $platform_levels = '1-4-16-64-1088-77248';
my @platform_levels_parts = split('-', $platform_levels);
my $cpus_number = $platform_levels_parts[$#platform_levels_parts];
my $cluster_size = $cpus_number/$platform_levels_parts[$#platform_levels_parts - 1];

my @results;
share(@results);

my $basic_file_name = "run_instances_platform-$execution_id";
my $experiment_folder = "$experiment_path/$basic_file_name";

mkdir $experiment_folder unless (-d $experiment_folder);

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('experiment');

$logger->info("creating queue\n");
my $q = Thread::Queue->new();
for my $variant (@variants) {
	for my $jobs_number (@jobs_numbers) {
		$q->enqueue([$variant, $jobs_number]);
	}
}
$q->end();

$logger->info("creating threads");
my @threads = map {threads->create(\&run_instance, $_)} (0..($threads_number - 1));

$logger->info("waiting for threads to finish");
$_->join() for (@threads);

$logger->info("writing results to file $experiment_folder/$basic_file_name.csv");
write_results_to_file();

$logger->info("done");

sub run_instance {
	my $id = shift;
	my $logger = get_logger('experiment');

	while (defined(my $instance = $q->dequeue_nb())) {
		my ($variant, $jobs_number) = @{$instance};

		$logger->info("thread $id running $variant, $jobs_number");

		my $trace = Trace->new_from_swf($trace_file);
		$trace->keep_first_jobs($jobs_number);
		$trace->fix_submit_times();
		my $schedule = Backfilling->new($trace, $cpus_number, $cluster_size, $variant, \@platform_levels_parts);
		$schedule->run();

		my @instance_results = (
			$cpus_number,
			$jobs_number,
			$cluster_size,
			$variant,
			$schedule->cmax(),
			$schedule->contiguous_jobs_number(),
			$schedule->local_jobs_number(),
			$schedule->locality_factor(),
			$schedule->bounded_stretch(10),
			$schedule->run_time(),
		);

		push @results, join(' ', @instance_results);
	}

	$logger->info("thread $id finished");
	return;
}

sub get_log_file {
	return "$experiment_folder/$basic_file_name.log";
}

sub write_results_to_file {
	my $file_name = "$experiment_folder/$basic_file_name.csv";
	open(my $file, '>', $file_name) or $logger->logdie("unable to create results file $file_name");

	print $file join(' ', (
			"CPUS_NUMBER",
			"JOBS_NUMBER",
			"CLUSTER_SIZE",
			"VARIANT",
			"CMAX",
			"CONT_JOBS",
			"LOC_JOBS",
			"LOC_FACTOR",
			"BOUNDED_STRETCH",
			"RUN_TIME"
		)) . "\n";

	print $file join(' ', $_) . "\n" for (@results);
	return;
}

