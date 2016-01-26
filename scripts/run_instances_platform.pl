#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Log::Log4perl qw(get_logger);

use Trace;
use Backfilling;

my ($execution_id) = @ARGV;

my $trace_file = '../swf/CEA-Curie-2011-2.1-cln-b1-clean2.swf';
my @variants = (BASIC, BEST_EFFORT_CONTIGUOUS, CONTIGUOUS, BEST_EFFORT_LOCAL, LOCAL);
my @jobs_numbers = (10);
my $experiment_path = 'experiment/run_schedule_platform';

my $results = [];
share($results);

my $basic_file_name = "run_instances_platform-";
my $experiment_folder = "$experiment_path/$basic_file_name";

unless (-d $experiment_folder) {
	mkdir $experiment_folder;
	$logger->info("experiment folder $experiment_folder created");
}

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('experiment');

$logger->info("reading trace");
my $trace = Trace->new_from_swf($trace_file);

$logger->info("Creating queue\n");
my $q = Thread::Queue->new();
$q->enqueue($_) for (0..($instances - 1));
$q->end();

$logger->info("Creating threads");
my @threads = map {threads->create(\&run_instance, $_)} (0..($threads_number - 1));

$logger->info("Waiting for threads to finish");
$_->join() for (@threads);

$run_time = time() - $run_time;

$logger->info("Writing results to file $experiment_folder/$basic_file_name.csv");
write_results_to_file();

$logger->info("Done");

sub run_instance {
	my $id = shift;

	my $logger = get_logger('test_time::run_instance');

	while (defined(my $instance = $q->dequeue_nb())) {
		$logger->info("Thread $id running $instance");

		my $trace_instance_file = "$experiment_path/swf/$instance.swf";

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

sub get_log_file {
	return "log/generate_platform.log";
}

