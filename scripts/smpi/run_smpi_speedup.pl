#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Time::HiRes qw(time);
use IO::Handle;
use Log::Log4perl qw(get_logger);

use Platform;

my ($benchmark) = @ARGV;

my @platform_levels = (1, 2, 4, 8, 16, 32, 64, 128);
my $platform = Platform->new(\@platform_levels);
my @speedups = $platform->generate_speedup($benchmark);

sub get_log_file {
	return 'log/run_smpilog';
}


