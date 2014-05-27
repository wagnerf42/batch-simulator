#!/usr/bin/perl

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
		push (@trace_data, @fields);
	}

}

print "@trace_data[0]";

close (FILE);
exit;
