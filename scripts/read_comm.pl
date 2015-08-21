#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Data::Dumper;

my ($input_file, $cpus_number) = @ARGV;

open(my $file, '<', $input_file) or die ('unable to open file');

my %comm = (
	'bcast' => 0,
	'send' => [(0) x $cpus_number],
);

my $line = <$file>;
my @line_fields = split(' ', $line);
my $source = $line_fields[0];

while (my $line = <$file>) {
	my @fields = split(' ', $line);

	next unless (defined $fields[1]);

	if ($fields[1] eq 'bcast') {
		$comm{'bcast'}++;
	} elsif ($fields[1] eq 'send') {
		$comm{'send'}->[$fields[2]]++;
	}
}

print "$source bcast $comm{'bcast'}\n";
print "$source send (" . join(',', @{$comm{'send'}}) . ")\n";
