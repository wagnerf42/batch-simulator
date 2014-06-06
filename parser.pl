#!/usr/bin/perl

use strict;
use warnings;

my @trace_data;
my $job = 0;
my $partitions_count = 0;
my @partitions;

# Prints one status field line
sub print_status_field {
	my @fields = @_;
	shift @fields;
	print "@fields\n";
}

open (FILE, $ARGV[0]);

while (my $line = <FILE>) {
	my @fields = split(' ', $line);

	next unless defined $fields[0];
	
	# Status line
	if ($fields[0] eq ';') { 
		if ($fields[1] eq 'Partition:') {
			$partitions_count++;
		}

	}

	# Job line
	elsif ($fields[0] ne ' ') {
		push @trace_data, [@fields];
	}

}

print "Total jobs: " . scalar @trace_data . "\n";
print 'Total partitions: ' . $partitions_count . "\n";

for (my $i = 0; $i < $partitions_count; $i++) {
	$partitions[$i] = 0;
}

for (my $i = 0; $i < scalar @trace_data; $i++) {
	$partitions[$trace_data[$i][15] - 1]++;
}

for (my $i = 0; $i < $partitions_count; $i++) {
	next unless ($partitions[$i] > 0);

	print 'Partition ' . ($i + 1) . ': ' . $partitions[$i] . "\n";
}

close (FILE);
exit;
