#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Time::HiRes qw(time);
use IO::Handle;
use Log::Log4perl qw(get_logger);

# Runs several benchmarks using SMPI

my ($cpus_number, $platform_file, $benchmark) = @ARGV;

my @platform_levels = (1, 2, 4, 8, 16, 32, 64, 128);
my @hosts = [[0, 1], [0, 2], [0, 4], [0, 8], [0, 16], [0, 32], [0, 64], [0, 128]];

my $smpi_script = './scripts/smpi/smpireplay.sh';


my $result = `./scripts/smpi/smpireplay.sh $cpus_number $platform_file /tmp/hosts-$nha $benchmark`;

unless ($result =~ /Simulation time (\d*\.\d*)/) {
	print STDERR "./scripts/smpi/smpireplay.sh $cpus_number $platform_file /tmp/hosts-$nha $benchmark\n";
	print STDERR "$result\n";
	die 'error running benchmark';
}

my $simulated_time = $1;

sub get_log_file {
	return 'log/run_smpilog';
}

