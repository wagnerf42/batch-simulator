#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Time::HiRes qw(time);

use Platform;
use Data::Dumper;

Log::Log4perl::init('log4perl.conf');

my $logger = get_logger('test');

my @levels = (1, 2, 4, 32);
my @available_cpus = (0..31);

for my $i (0..23) {
	my $position = int(rand(32 - $i));
	splice(@available_cpus, $position, 1);
}

$logger->debug("available cpus: @available_cpus");

for my $norm (1, 2, 3, 4, 5, 6) {
	my $platform = Platform->new(\@levels, \@available_cpus, $norm);
	$platform->build_structure();
	#print Dumper($platform->{root});
	my @selected_cpus = $platform->choose_cpus(6);
	$logger->info("norm: $norm, cpus: @selected_cpus");
}

