#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Data::Dumper;

my ($input_file) = @ARGV;

open(my $file, '<', $input_file) or die ('unable to open file');

my $compute_total = 0.0;

while (my $line = <$file>) {
	my @line_parts = split(' ', $line);

	if ($line_parts[1] eq 'compute') {
		$compute_total += $line_parts[2]/1.0e6;
	}
}

print "$compute_total\n";

