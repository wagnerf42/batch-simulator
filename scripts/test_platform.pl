#!/usr/bin/env perl
use strict;
use warnings;

use Platform;
use Data::Dumper;

my @levels = (1, 3, 6, 12);
my $platform = Platform->new(\@levels);
my @available_cpus = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11); 
$platform->build_structure(\@available_cpus);

print Dumper($platform->{structure});


