#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Time::HiRes qw(time);

use Platform;
use Data::Dumper;

Log::Log4perl::init('log4perl.conf');

my @levels = (1, 3, 6);
my @available_cpus = (0..5);

my $platform = Platform->new(\@levels, \@available_cpus);
$platform->build_structure();
#print Dumper($platform->{root});
my @selected_cpus = $platform->choose_cpus(1);
print Dumper(@selected_cpus);

