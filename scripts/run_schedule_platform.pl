#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Log::Log4perl qw(get_logger);

use Trace;
use Backfilling;
use Basic;

my ($jobs_number) = @ARGV;
die 'arguments' unless (defined $jobs_number);

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('experiment');

#my $trace_file = '../swf/CEA-Curie-2011-2.1-cln-b1-clean2.swf';
my $trace_file = '/tmp/test.swf';
my @platform_levels = (1, 2, 4, 8, 16);
my $cpus_number = $platform_levels[$#platform_levels];
my $cluster_size = $cpus_number/$platform_levels[$#platform_levels - 1];
my $stretch_bound = 10;
my $reduction_algorithm = Basic->new(\@platform_levels);

my $trace = Trace->new_from_swf($trace_file);
$trace->fix_submit_times();
$trace->remove_large_jobs($cpus_number);
$trace->keep_first_jobs($jobs_number);

my $platform = Platform->new(\@platform_levels);

my $schedule = Backfilling->new($reduction_algorithm, $platform, $trace);
$schedule->run();

#my $jobs_number = @{$schedule->trace()->jobs()};

my @results = (
	#$cpus_number,
	#$jobs_number,
	#$cluster_size,
	#$variant,
	#$schedule->cmax(),
	#$schedule->contiguous_jobs_number(),
	#$schedule->local_jobs_number(),
	#$schedule->locality_factor(),
	#$schedule->bounded_stretch(10),
	$schedule->run_time(),
);

print STDOUT join(' ', @results) . "\n";
$schedule->tycat();

sub get_log_file {
	return "log/generate_platform.log";
}


