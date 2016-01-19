#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Log::Log4perl qw(get_logger :no_extra_logdie_message);

use Platform;
use Trace;
use Backfilling;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('test');

my ($trace_file, $cpus_number, $cluster_size) = @ARGV;

my $variant = 5;
my $levels = '1-2-4-8';

my $trace = Trace->new_from_swf($trace_file);
my $schedule = Backfilling->new($trace, $cpus_number, $cluster_size, $variant, $levels);
$schedule->run();

$logger->info("script finished");

sub get_log_file {
	return "log/generate_platform.log";
}


