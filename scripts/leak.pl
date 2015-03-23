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
		$nhack->{$fields[0]}->{$fields[1]} = $fields[2];
	}
}

for my $key (keys %{$nhack->{allocated}}) {
	print "id $key block $nhack->{allocated}->{$key}\n" unless defined $nhack->{freed}->{$key};
}

close($file);

