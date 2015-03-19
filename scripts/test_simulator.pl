#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger);

use Trace;
use Backfilling;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger();
my $json_file = $ARGV[0];

my $schedule = Backfilling->new_simulation(undef, BASIC, $json_file);
$schedule->run();

print STDERR "Done\n";

