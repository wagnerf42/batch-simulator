#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Time::HiRes qw(time);
use IO::Handle;
use Log::Log4perl qw(get_logger);

use Platform;

# Runs several benchmarks using SMPI

my ($benchmark) = @ARGV;

my @platform_levels = (1, 2, 4, 8, 16, 32, 64, 128);

my $platform = Platform->new(\@platform_levels);
my @speedups = $platform->generate_speedup($benchmark);
print Dumper(@speedups);
die;

#for my $hosts_config (@{$hosts_configs}) {
#	save_hosts_file($hosts_config);
#
#	my $result = `$smpi_script $cpus_number $platform_file $hosts_file $benchmark 2>&1`;
#
#	unless ($result =~ /Simulation time (\d*\.\d*)/) {
#		print STDERR "$smpi_script $cpus_number $platform_file $hosts_file $benchmark\n";
#		print STDERR "$result\n";
#		die 'error running benchmark';
#	}
#
#	my $distance = $platform->level_distance($hosts_config->[0], $hosts_config->[1]);
#	print "$hosts_config->[1] $distance $1\n";
#}

sub get_log_file {
	return 'log/run_smpilog';
}

#sub save_hosts_file {
#	my $hosts_config = shift;
#
#	open(my $file, '>', $hosts_file);
#	print $file join("\n", @{$hosts_config}) . "\n";
#	close($file);
#}

