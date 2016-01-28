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

my ($trace_file) = @ARGV;

my @levels = (1, 4, 16, 64, 1088, 77248);
#my @levels = (1, 4, 16, 64);
my $variant = 5;
my $cpus_number = $levels[$#levels];
my $cluster_size = $levels[$#levels]/$levels[$#levels - 1];

my $trace = Trace->new_from_swf($trace_file);
$trace->keep_first_jobs(700);
my $schedule = Backfilling->new($trace, $cpus_number, $cluster_size, $variant, \@levels);
$schedule->run();

$logger->info("script finished");

sub get_log_file {
	return "log/generate_platform.log";
}


