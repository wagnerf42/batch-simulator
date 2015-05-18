#!/usr/bin/env perl
use strict;
use warnings;

use ExecutionProfile;

my $space = ExecutionProfile->new(10);
$space->tycat();
$space->add_task(0,3,4);
$space->tycat();
#$space->add_task(1,2,4);
#$space->tycat();

print STDERR "Done\n";
