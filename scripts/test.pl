#!/usr/bin/env perl

use Profile;
use ProcessorRange;

my $r = ProcessorRange->new(0,5);
my $small_profile = Profile->new(10, $r, 10);
my $scalar = 30;

print "$small_profile\n";

for my $scalar (0..22) {
	my $res = Profile::loose_comparison($small_profile, $scalar);
	my $res2 = Profile::three_way_comparison($small_profile, $scalar);
	#print "$scalar res $res\n" if ($res);
	#print "$scalar res2 $res2\n" if ($res2);
	print "scalar $scalar res $res res2 $res2\n";
}

my $p2 = Profile->new(0, $r, 10);
print "$p2\n";
my $res3 = Profile::loose_comparison($p2, $small_profile);
my $res4 = Profile::three_way_comparison($p2, $small_profile);
print "res3 $res3 res4 $res4\n";


#print $small_profile->three_way_comparison($scalar) . "\n";



