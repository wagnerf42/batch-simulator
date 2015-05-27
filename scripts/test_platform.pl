#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Time::HiRes qw(time);

use Platform;
use Data::Dumper;

Log::Log4perl::init('log4perl.conf');

my @levels = (1, 3, 6, 12);
my @available_cpus = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11); 

my $platform = Platform->new(\@levels, \@available_cpus);
$platform->build_structure();
#print Dumper($platform->{root});
my @selected_cpus = $platform->choose_cpus(2);

