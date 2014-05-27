#!/usr/bin/perl

use Data::Dumper qw(Dumper);

my @trace_data;
my $job = 0;

# Prints one status field line
sub print_status_field {
	my @fields = @_;

	print "$fields[1]";

	foreach $field (2 .. scalar @fields) {
		print " $fields[$field]";
	}

	print "\n";
}

open (FILE, 'small.swf');

while (<FILE>) {
	chomp;
	@fields = split(" ");

	# Status line
	if ($fields[0] == ";") { 
		print_status_field(@fields);
	}

	# Job line
	if ($fields[0] != " ") {
		foreach $field (0 .. 17) {
			$trace_data[$job][$field] = $fields[$field];
		}

		$job++;
	}

}

print Dumper \@trace_data;
close (FILE);
exit;
