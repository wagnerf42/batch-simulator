#!/usr/bin/perl
use strict;
use warnings;

use Data::Dumper;

my ($filename) = @ARGV;
open (my $file, '<', $filename) or die;
my $nhack;

while (defined(my $line = <$file>)) {
	my @fields = ($line =~ /(allocated|freed)\s(\d+)\sblock\s(\d+)/);
	if (@fields == 3) {
		if ($fields[0] eq 'freed') {
			delete $nhack->{$fields[1]};
		} else {
			$nhack->{$fields[1]} = $fields[2];
		}
	}
}

for my $key (keys %{$nhack}) {
	print "id $key block $nhack->{$key}\n";
}

close($file);

