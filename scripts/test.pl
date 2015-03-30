#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger);

use Trace;
use Backfilling;

my ($trace_file, $jobs_number, $cpus_number) = @ARGV;
my $cluster_size = 16;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('test');

$logger->info('reading trace');
my $trace = Trace->new_from_swf($trace_file);
$trace->remove_large_jobs($cpus_number);
$trace->keep_first_jobs($jobs_number);
$trace->fix_submit_times();
$trace->reset_jobs_numbers();
#$trace->write_to_file("$jobs_number-$cpus_number.swf");

$logger->info('running scheduler');
my $schedule = Backfilling->new($trace, $cpus_number, $cluster_size, BASIC);
$schedule->run();
$schedule->tycat() if $logger->is_debug();

#$logger->debug("$jobs_number $cpus_number " . $schedule->{schedule_time});
$logger->info('done');

