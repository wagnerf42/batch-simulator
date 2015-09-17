#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Data::Dumper;

# Reads a trace file generated from SMPI and prints the total amount of compute
# done by each CPU

my ($trace_file_name) = @ARGV;

my @trace_file_names;
my @rank_computations;

open(my $file, '<', $trace_file_name) or die ('unable to open file');
while (my $line = <$file>) {
	chomp $line;
	push @trace_file_names, $line;
}

@rank_computations = map { read_trace_file($_) } (@trace_file_names);
print benchmark_name($trace_file_name) . " " . join(' ', @rank_computations) . "\n";

sub read_trace_file {
	my $file_name = shift;

	my $compute_total = 0.0;

	open(my $file, '<', $file_name) or die ('unable to open file');

	while (my $line = <$file>) {
		my @line_parts = split(' ', $line);

		if ($line_parts[1] eq 'compute') {
			$compute_total += $line_parts[2]/1.0e6;
		}
	}

	close($file);
	return $compute_total;
}

sub benchmark_name {
	my $file_name = shift;

	my $base_name = `basename $file_name .trace`;
	my @base_name_parts = split('-', $base_name);
	return $base_name_parts[0];
}

