#!/usr/bin/perl

# Prints one status field line
sub print_status_field {
	my @fields = @_;

	print "$fields[1]";

	foreach $field (2 .. scalar @fields) {
		print " $fields[$field]";
	}

	print "\n";
}

# Parses one job line
sub parse_data_fields {
	my @fields = @_;

	print "Job Number: $fields[0]\n";
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
	if ($fields[9] != " ") {
		parse_data_fields(@fields);
	}

}

close (FILE);
exit;
