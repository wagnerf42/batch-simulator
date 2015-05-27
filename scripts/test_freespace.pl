#!/usr/bin/env perl
use strict;
use warnings;

use ExecutionProfile;

my $space = ExecutionProfile->new(10);
$space->tycat();
my $range_task = $space->add_task(0,3,4);
$space->tycat();
#$space->add_task(0,4,5);
#$space->tycat();
$space->remove_task(0,3,$range_task);
$space->tycat();
#$space->add_task(0,1,3);
#$space->tycat();
#$space->{profile_tree}->tycat();

print STDERR "Done\n";
