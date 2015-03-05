#!/usr/bin/env perl

use Profile;
use ProcessorRange;

my $r = ProcessorRange->new(0,5);
my $small_profile = Profile->new(10, $r, 10);
my $scalar = 30;

print "$small_profile\n";

for my $scalar (0..21) {
	print "test $scalar a\n" if ($scalar > $small_profile);
	print "test $scalar b\n" if ($small_profile > $scalar);
}

#print $small_profile->three_way_comparison($scalar) . "\n";



