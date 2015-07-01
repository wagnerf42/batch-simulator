#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Log::Log4perl qw(get_logger :no_extra_logdie_message);

use Platform;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('test');

my @levels = (1, 2, 4, 8, 64);
my @available_cpus = (0..($levels[-1] - 1));

# Put everything in the log file
$logger->info("platform: @levels");

my $platform = Platform->new(\@levels, \@available_cpus, 1);
$platform->build_structure();
$platform->build_platform_xml();
$platform->save_platform_xml('platform.xml');

sub get_log_file {
	return "generate_permutations.log";
}


