#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Data::Dumper;

# Reads a list of permutations with costs and selects one for each cost value

my ($file_name, $collumn) = @ARGV;

my %seen;

open(my $file, '<', $file_name) or die ('unable to open file');

# Ignore first line
<$file>;

while (my $line = <$file>) {
	chomp $line;
	my @line_parts = split(' ', $line);

	unless (exists $seen{$line_parts[$collumn]}) {
		$seen{$line_parts[$collumn]} = undef;
		print "$line_parts[0]\n";
	}
}

