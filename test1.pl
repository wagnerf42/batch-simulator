#!/usr/bin/perl

open (FILE, 'names.tsv');

while (<FILE>) {
	chomp;
	($name, $email, $phone) = split(" ");

	print "Name: $name\n";
	print "Email: $email\n";
	print "Phone: $phone\n";
	print "\n";
}

close (FILE);
exit;
