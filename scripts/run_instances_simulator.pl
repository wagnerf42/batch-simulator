#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use threads;
use threads::shared;
use Thread::Queue;
use Log::Log4perl qw(get_logger);
use Time::HiRes qw(time);

use Trace;
use Backfilling;

my $trace_file = '../swf/CEA-Curie-2011-2.1-cln-b1-clean2.swf';
my $batsim = '../batsim/build/batsim';
my $schedule_script = 'scripts/run_schedule_simulator.pl';
my $platform_file = '../batsim/platforms/small_platform.xml';
my $experiment_path = 'experiment/run_instances_simulator';
my $instances = 1;
my $jobs_number = 10;
my $cpus_number = 4;
my $cluster_size = 2;
my $threads_number = 1;
my @backfilling_variants = (BASIC);
#my @backfilling_variants = (BASIC, BEST_EFFORT_CONTIGUOUS, CONTIGUOUS, BEST_EFFORT_LOCAL, LOCAL);

$SIG{INT} = \&catch_signal;

my $results = [];
share($results);

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('test_time');

$logger->info("Reading trace");
my $trace = Trace->new_from_swf($trace_file);
$trace->remove_large_jobs($cpus_number);
$trace->reset_submit_times();
$trace->reset_jobs_numbers();

# Create a directory to store the output
my $basic_file_name = "run_instances-$jobs_number-$instances-$cpus_number-$execution_id";
my $experiment_folder = "$experiment_path/$basic_file_name";
$logger->info("Creating experiment folder $experiment_folder");
mkdir $experiment_folder unless -f $experiment_folder;

$logger->info("Creating queue\n");
my $q = Thread::Queue->new();
$q->enqueue($_) for (0..($instances - 1));
$q->end();

my $run_time = time();

$logger->info("Creating threads");
my @threads = map {threads->create(\&run_instance, $_)} (0..($threads_number - 1));

$logger->info("Waiting for threads to finish");
while ((my $running_threads = threads->list()) > 0) {
	my @joinable_threads = threads->list(threads::joinable);
	$_->join() for (@joinable_threads);
	sleep(5);
}

$database->update_run_time($execution_id, time() - $run_time);

$logger->info("Writing results to file $experiment_folder/$basic_file_name.csv");
write_results_to_file();

$logger->info("Done");

sub run_instance {
	my $id = shift;
	my $logger = get_logger('test_time::run_instance');

	# Exit the thread if a signal is received
	$SIG{INT} = sub { $logger->info("Killing thread $id"); threads->exit(); };

	while (defined(my $instance = $q->dequeue_nb())) {
		$logger->info("Thread $id running $instance");

		my $trace_instance = Trace->new_from_trace($trace, $jobs_number);

		my $json_file = "$experiment_folder/$instance.json";
		$trace_instance->save_json($json_file, $cpus_number);

		my $results_instance = [];
		share($results_instance);

		for my $backfilling_variant (@backfilling_variants) {
			my $schedule_thread = threads->create(\&run_schedule, $backfilling_variant, $json_file);
			sleep(1);
			my $batsim_thread = threads->create(\&run_batsim, $json_file);

			my $batsim_result = $batsim_thread->join();
			my $schedule_result = $schedule_thread->join();

			push @{$results_instance}, (
				$schedule_result->{cmax},
				$schedule_result->{contiguous_jobs},
				$schedule_result->{local_jobs},
				$schedule_result->{locality_factor},
				$schedule_result->{run_time},
			);
		}

		push @{$results_instance}, $trace_id;
		$results->[$instance] = $results_instance;
	}

	$logger->info("Thread $id finished");
	return;
}

sub run_schedule {
	my $backfilling_variant = shift;
	my $json_file = shift;

	my $schedule_result = `$schedule_script $cluster_size $backfilling_variant $json_file`;
	my ($cmax, $contiguous_jobs_number, $local_jobs_number, $locality_factor, $run_time) = split(' ', $schedule_result);
	
	my %instance_info = (
		algorithm => $backfilling_variant,
		cmax => $cmax,
		contiguous_jobs => $contiguous_jobs_number,
		local_jobs => $local_jobs_number,
		locality_factor => $locality_factor,
		run_time => $run_time,
	);

	return \%instance_info;
}

sub run_batsim {
	my $json_file = shift;

	my $batsim_result =  `$batsim $platform_file $json_file`;
	return $batsim_result;
}

sub write_results_to_file {
	open (my $file, '>', "$experiment_folder/$basic_file_name.csv") or die "unable to open $experiment_folder/$basic_file_name";

	print $file join(' ',
		'FIRST_CMAX', 'FIRST_CONTJ', 'FIRST_LOCJ', 'FIRST_LOCF', 'FIRST_RT',
		'BECONT_CMAX', 'BECONT_CONTJ', 'BECONT_LOCJ', 'BECONT_LOCF', 'BECONT_RT',
		'CONT_CMAX', 'CONT_CONTJ', 'CONT_LOCJ', 'CONT_LOCF', 'CONT_RT',
		'BELOC_CMAX', 'BELOC_CONTJ', 'BELOC_LOCJ', 'BELOC_LOCF', 'BELOC_RT',
		'LOC_CMAX', 'LOC_CONTJ', 'LOC_LOCJ', 'LOC_LOCF', 'LOC_RT',
		'TRACE_ID',
	) . "\n";

	for my $results_item (@{$results}) {
		print $file join(' ', @{$results_item}) . "\n";
	}

	close($file);
	return;
}

sub catch_signal {
	my $signame = shift;
	print STDERR "Received SIG$signame signal\n";
	$_->kill('INT')->detach() for @threads;
	return;
}


