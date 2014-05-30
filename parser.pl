#!/usr/bin/perl


use strict;
use warnings;

my @trace_data;
my $job = 0;

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
		print_status_field(@fields);
	}

	# Job line
	if ($fields[0] ne ' ') {
		push @trace_data, [@fields];
	}

}

print "Total jobs: " . scalar @trace_data . "\n";

#foreach $job (0 .. scalar @trace_data -1) {
#	print "Job Number: $trace_data[$job][0]\n";
#}

close (FILE);
exit;
