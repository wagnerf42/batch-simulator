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
use Database;

my $trace_file = '../swf/CEA-Curie-2011-2.1-cln-b1-clean2.swf';
my $schedule_script = 'scripts/run_schedule.pl';
my $experiment_path = 'experiment/run_instances';
my $database_file = 'experiment/parser.db';
my $instances = 1;
my $jobs_number = 300;
my $cpus_number = 512;
my $cluster_size = 16;
my $threads_number = 6;
my @backfilling_variants = (BASIC);
#my @backfilling_variants = (BASIC, BEST_EFFORT_CONTIGUOUS, CONTIGUOUS, BEST_EFFORT_LOCAL, LOCAL);

my $results = [];
share($results);

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('test_time');

# Basic database part
my $database = Database->new($database_file);
$database->prepare_tables();
my $execution_id = $database->add_execution({
		trace_file => $trace_file,
		script_name => "scripts/run_instances.pl",
		jobs_number => $jobs_number,
		cpus_number => $cpus_number,
		cluster_size => $cluster_size,
		git_revision => `git rev-parse HEAD`,
	});

$logger->info("Reading trace");
my $trace = Trace->new_from_swf($trace_file);
$trace->remove_large_jobs($cpus_number);
$trace->reset_submit_times();
$trace->reset_jobs_numbers();

$database->add_trace(undef, {
		execution => $execution_id,
		generation_method => "remove large jobs, reset submit times, reset jobs numbers",
		trace_file => $trace_file,
	});

# Create a directory to store the output
my $basic_file_name = "run_instances-$jobs_number-$instances-$cpus_number-$execution_id";
my $experiment_folder = "$experiment_path/$basic_file_name";

unless (-d $experiment_folder) {
	mkdir $experiment_folder;
	$logger->info("experiment folder $experiment_folder created");
	die;
}

$logger->info("Creating queue\n");
my $q = Thread::Queue->new();
$q->enqueue($_) for (0..($instances - 1));
$q->end();

my $run_time = time();

$logger->info("Creating threads");
my @threads = map {threads->create(\&run_instance, $_)} (0..($threads_number - 1));

$logger->info("Waiting for threads to finish");
$_->join() for (@threads);

$run_time = time() - $run_time;
$database->update_run_time($execution_id, $run_time);

$logger->info("Writing results to file $experiment_folder/$basic_file_name.csv");
write_results_to_file();

$logger->info("Done");

sub run_instance {
	my $id = shift;

	my $logger = get_logger('test_time::run_instance');
	my $database = Database->new($database_file);

	while (defined(my $instance = $q->dequeue_nb())) {
		$logger->info("Thread $id running $instance");

		my $trace_instance_file = "$experiment_folder/$instance.swf";

		my $trace_id = $database->add_trace(undef, {
				execution => $execution_id,
				generation_method => "random jobs",
			});

		my $results_instance = [];
		share($results_instance);

		for my $backfilling_variant (@backfilling_variants) {
			my $schedule_thread = threads->create(\&run_schedule, $trace_instance_file, $backfilling_variant);
			my $schedule_result = $schedule_thread->join();

			push @{$results_instance}, (
				$schedule_result->{cmax},
				$schedule_result->{contiguous_jobs},
				$schedule_result->{local_jobs},
				$schedule_result->{locality_factor},
				$schedule_result->{run_time},
			);

			$database->add_instance({
					trace => $trace_id,
					algorithm => $BACKFILLING_VARIANT_STRINGS[$backfilling_variant],
					cmax => $schedule_result->{cmax},
					local_jobs => $schedule_result->{local_jobs},
					contiguous_jobs => $schedule_result->{contiguous_jobs},
					locality_factor => $schedule_result->{locality_factor},
					run_time => $schedule_result->{run_time},
				});
		}

		push @{$results_instance}, $instance;
		$results->[$instance] = $results_instance;
	}

	$logger->info("Thread $id finished");
	return;
}

sub run_schedule {
	my $trace_file = shift;
	my $backfilling_variant = shift;


	my $schedule_result = `$schedule_script $trace_file $cpus_number $cluster_size $backfilling_variant`;
	my ($cmax, $contiguous_jobs_number, $local_jobs_number, $locality_factor, $run_time) = split(' ', $schedule_result);

	my %result = (
		cmax => $cmax,
		contiguous_jobs => $contiguous_jobs_number,
		local_jobs => $local_jobs_number,
		locality_factor => $locality_factor,
		run_time => $run_time,
	);

	return \%result;
}

sub write_results_to_file {
	open (my $file, '>', "$experiment_folder/$basic_file_name.csv") or die "unable to open $experiment_folder/$basic_file_name";

	my @headers;
	for my $backfilling_variant (@backfilling_variants) {
		push @headers, map { $BACKFILLING_VARIANT_STRINGS[$backfilling_variant] . '_' . $_ } ("CMAX", "CJOBS", "LJOBS", "LFACTOR", "RTIME");
	}

	push @headers, "INSTANCE";
	print $file join(' ', @headers) . "\n";

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


