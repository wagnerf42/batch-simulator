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
use Platform;

my ($execution_id) = @ARGV;

my $trace_file = '../swf/CEA-Curie-2011-2.1-cln-b1-clean2.swf';
my @variants = (
	BASIC,
	#BEST_EFFORT_CONTIGUOUS,
	#CONTIGUOUS,
	#BEST_EFFORT_LOCAL,
	#LOCAL,
	#BEST_EFFORT_PLATFORM,
	#PLATFORM
);

my $experiment_path = 'experiment/run_instances_platform';
my $basic_file_name = "run_instances_platform-$execution_id";
my $experiment_folder = "$experiment_path/$basic_file_name";
my @jobs_numbers = (2);
my $threads_number = 1;
my $platform_levels = '1-2-4-8';
my @platform_levels_parts = split('-', $platform_levels);
my $platform_file = "$experiment_folder/platform.xml";
my $cpus_number = $platform_levels_parts[$#platform_levels_parts];
my $cluster_size = $cpus_number/$platform_levels_parts[$#platform_levels_parts - 1];
my $comm_factor = '1e4';
my $comp_factor = '1e5';
my $schedule_script = 'scripts/run_schedule_platform.pl';
my $batsim = '/home/fernando/Documents/batsim/build/batsim';
my $delay = 15;

my @results;
share(@results);

mkdir $experiment_folder unless (-d $experiment_folder);

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('experiment');

$logger->info("preparing trace files");
for my $jobs_number (@jobs_numbers) {
	my $trace = Trace->new_from_swf($trace_file);
	$trace->remove_large_jobs($cpus_number);
	$trace->keep_first_jobs($jobs_number);
	$trace->fix_submit_times();
	$trace->reset_jobs_numbers();
	$trace->write_to_file("$experiment_folder/$basic_file_name-$jobs_number.swf");
	$trace->save_json("$experiment_folder/$basic_file_name-$jobs_number.json", $cpus_number, $comm_factor, $comp_factor);
}

my $platform = Platform->new(\@platform_levels_parts);
$platform->build_platform_xml();
$platform->save_platform_xml($platform_file);

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
#write_results_to_file();

$logger->info("done");

sub run_instance {
	my $id = shift;
	my $logger = get_logger('experiment');

	while (defined(my $instance = $q->dequeue_nb())) {
		my ($variant, $jobs_number) = @{$instance};

		my $json_file = "$experiment_folder/$basic_file_name-$jobs_number.json";
		my $socket_file = "$experiment_folder/$basic_file_name-$variant-$jobs_number.socket";

		$logger->info("thread $id running $variant, $jobs_number");
		my $batsim_thread = threads->create(\&run_batsim, $socket_file, $json_file);
		my $schedule_thread = threads->create(\&run_schedule, $json_file, $variant, $socket_file);

		$batsim_thread->join();
		$schedule_thread->join();
	}

	$logger->info("thread $id finished");
	return;
}

sub run_schedule {
	my $json_file = shift;
	my $variant = shift;
	my $socket_file = shift;

	my $schedule_result = `$schedule_script $json_file $cpus_number $cluster_size $variant $platform_levels $delay $socket_file`;
	return $schedule_result;
}

sub run_batsim {
	my $socket_file = shift;
	my $json_file = shift;

	#my $batsim_result =  `$batsim -s $socket_file -m 'master_host0' $platform_file $json_file 2>/dev/null`;
	my $batsim_result =  `$batsim -s $socket_file -m 'master_host0' $platform_file $json_file`;
	return $batsim_result;
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

