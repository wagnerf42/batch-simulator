#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Data::Dumper;
use File::Slurp;

my @cpus = (1, 2, 4, 8, 16, 32, 64);
my $benchmark_class = 'C';
my @benchmarks = ('cg', 'ft', 'lu');

print "CPUS cg ft lu\n";

for my $cpu (@cpus) {
	my @simulated_times;

	for my $benchmark (@benchmarks) {
		my $file_name = "benchmarks/$benchmark.$benchmark_class.$cpu-$cpu.log";
		print STDERR "reading $file_name\n";
		my $text = read_file($file_name);

		unless ($text =~ /Simulated time: (\d*\.\d*)/) {
			die 'error reading one of the files';
		}

		push @simulated_times, $1;
	}

	print "$cpu " . join(' ', @simulated_times) . "\n";
}
