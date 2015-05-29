#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Time::HiRes qw(time);

use Platform;
use Data::Dumper;

Log::Log4perl::init('log4perl.conf');

my $logger = get_logger('test_platform.pl');

my @levels = (1, 2, 4, 32);
my @available_cpus = (0..31);

my $platform = Platform->new(\@levels, \@available_cpus, 4);
$platform->build_structure();
#print Dumper($platform->{root});
my @selected_cpus = $platform->choose_cpus(6);
$logger->info("cpus: @selected_cpus");

