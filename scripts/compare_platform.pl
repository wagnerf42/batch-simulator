#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Time::HiRes qw(time);
use Algorithm::Permute;
use Data::Dumper;
use threads;
use Thread::Queue;

use Platform;

Log::Log4perl::init('log4perl.conf');

my $logger = get_logger('test');

my @levels = (1, 2, 4, 32);
my @available_cpus = (0..($levels[$#levels] - 1));
my @benchmarks = ('benchmarks/cg.B.8', 'benchmarks/ft.B.8', 'benchmarks/lu.B.8');
my $execution_id = 1;
my $removed_cpus_number = 24;
my $required_cpus = 8;
my $threads_number = 1;

for my $i (0..($removed_cpus_number - 1)) {
	my $position = int(rand($levels[$#levels] - 1 - $i));
	splice(@available_cpus, $position, 1);
}

# Put everything in the log file
$logger->info("platform: @levels");
$logger->info("available cpus: @available_cpus");
$logger->info("removed cpus: $removed_cpus_number");
$logger->info("required cpus: $required_cpus");

my $platform = Platform->new(\@levels, \@available_cpus, 1);
$platform->build_structure();
$platform->build_platform_xml();
$platform->save_platform_xml('platform.xml');

my $iterator = Algorithm::Permute->new(\@available_cpus);
my $permutation_number = 0;

$logger->info("creating queue\n");
my $q = Thread::Queue->new();
while (my @permutation = $iterator->next()) {
	$logger->info("permutation $permutation_number: @permutation");
	$q->enqueue($permutation_number);

	$permutation_number++;
	last if ($permutation_number == 3);
}
$q->end();

$logger->info("creating threads");
my @threads = map { threads->create(\&run_instance, $_) } (0..($threads_number - 1));

$logger->debug("waiting for threads to finish");
$_->join() for (@threads);

sub write_host_file {
	my $permutation = shift;
	my $file_name = shift;

	open(my $file, '>', $file_name);

	print $file "$_\n" for (@{$permutation});
	return;
}

sub run_instance {
	my $id = shift;

	my $hostfile = "permutation-$id";
	my $filename = "compare_platform-$execution_id-$id.log";

	open(my $file, '>', $filename);

	while (defined(my $instance = $q->dequeue_nb())) {
		#write_host_file($instance, $hostfile);

		continue;

		for my $benchmark (@benchmarks) {
			print "permutation @{$instance} $benchmark\n" ;
			my $result = `echo ./smpireplay.sh $required_cpus $hostfile $benchmark`;
			print $file $result;
		}
	}

	#unlink($hostfile);

	return;
}

sub get_log_file {
	return "compare_platform-$execution_id.log";
}


