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

open (FILE, 'small.swf');

while (<FILE>) {
	@fields = split(" ");

	if ($fields[0] == ";") { 
		print_status_field(@fields);
	}

}

close (FILE);
exit;
