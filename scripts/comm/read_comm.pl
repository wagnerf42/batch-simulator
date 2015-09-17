#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Data::Dumper;

my ($input_file, $cpus_number) = @ARGV;

open(my $file, '<', $input_file) or die ('unable to open file');

my @sends_number;

for my $cpu_number (0..($cpus_number - 1)) {
	$sends_number[$cpu_number] = [(0) x $cpus_number];
}

while (my $line = <$file>) {
	chomp $line;
	my @line_fields = split(' ', $line);
	my ($source, $destination, $size) = @line_fields[4..6];
	$sends_number[$source]->[$destination] += 1;
}

for my $cpu_number (0..($cpus_number - 1)) {
	print join(' ', @{$sends_number[$cpu_number]}) . "\n";
}

