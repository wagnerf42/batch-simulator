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

open (FILE, $ARGV[0]);

while (<FILE>) {
	@fields = split(" ");

	# Status line
	if ($fields[0] == ";") { 
		#print_status_field(@fields);
	}

	# Job line
	if ($fields[0] != " ") {
		#print "Job: @fields\n";
		foreach $field (0 .. 17) {
			$trace_data[$job][$field] = $fields[$field];
		}

		$job++;
	}

}

print "Total jobs: " . scalar @trace_data . "\n";

#foreach $job (0 .. scalar @trace_data -1) {
#	print "Job Number: $trace_data[$job][0]\n";
#}

close (FILE);
exit;
