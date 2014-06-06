#!/usr/bin/perl

use strict;
use warnings;

my @trace_data;
my @status_data;
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
		push @status_data, [@fields];

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

# The partitions in the SWF file start from 1 so I shift them one position
for (my $i = 0; $i < scalar @trace_data; $i++) {
	$partitions[$trace_data[$i][15] - 1]++;
}

for (my $i = 0; $i < $partitions_count; $i++) {
	next unless ($partitions[$i] > 0);

	print 'Partition ' . ($i + 1) . ': ' . $partitions[$i] . "\n";
}

#for (my $i = 0; $i < @trace_data; $i++) {
#		print join (" ", @{$trace_data[$i]}) . "\n";
#}

for (my $i = 0; $i < @status_data; $i++) {
	if (($status_data[$i][1] ne 'Partition:') || (($status_data[$i][1] eq 'Partition:') && ($partitions[$status_data[$i][2] - 1] > 0))) {
		print join(" ", @{$status_data[$i]}) . "\n";
	}
}

close (FILE);
exit;
