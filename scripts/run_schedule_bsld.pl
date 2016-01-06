#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Log::Log4perl qw(get_logger);

use Trace;
use Backfilling;

my ($trace_file, $cpus_number, $cluster_size, $variant) = @ARGV;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger();

my $trace = Trace->new_from_swf($trace_file);
$trace->remove_large_jobs($cpus_number);

my $schedule = Backfilling->new($trace, $cpus_number, $cluster_size, $variant);
$schedule->run();

sub get_log_file {
	return 'log/run_schedule_bsld.log';
}


