#!/usr/bin/env perl
use strict;
use warnings;

use ExecutionProfile;

my $space = ExecutionProfile->new(10);
$space->tycat();
$space->add_task(undef,3,4);
$space->tycat();
$space->add_task(undef,4,5);
$space->tycat();

print STDERR "Done\n";
