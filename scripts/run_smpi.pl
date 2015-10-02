#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Time::HiRes qw(time);
use IO::Handle;

# Runs several benchmarks using SMPI

my ($cpus_number, $permutations_file, $platform_file, $benchmark, $output_file) = @ARGV;

open(my $permutations_fd, '<', $permutations_file) or die ('unable to open file');
my $header = <$permutations_fd>;
chomp $header;

open(my $output_fd, '>', $output_file) or die ('unable to open file');
$output_fd->autoflush(1);
print $output_fd "$header st\n";

my $nha = 0;

while (my $permutation_line = <$permutations_fd>) {
	chomp $permutation_line;
	my @permutation_line_parts = split(' ', $permutation_line);
	write_host_file($permutation_line_parts[0], "/tmp/hosts-$nha");

	my $result = `./scripts/smpi/smpireplay.sh $cpus_number $platform_file /tmp/hosts-$nha $benchmark`;

	unless ($result =~ /Simulation time (\d*\.\d*)/) {
		print STDERR "./scripts/smpi/smpireplay.sh $cpus_number $platform_file /tmp/hosts-$nha $benchmark\n";
		print STDERR "$result\n";
		die 'error running benchmark';
	}

	my $simulated_time = $1;
	print $output_fd "$permutation_line $1\n";
	$nha++;
}

sub write_host_file {
	my $permutation = shift;
	my $file_name = shift;

	my @permutation_parts = split('-', $permutation);

	open(my $file, '>', $file_name);

	print $file "$_\n" for (@permutation_parts);
	return;
}
