#!/usr/bin/env perl

use Perl::Critic qw(critique);

my @files = (<*.pm>);
for my $file (@files) {
	my @violations = critique( {-severity => 4}, $file );
	print "***** $file *****\n" if @violations;
	print $_ for @violations;
}

