#!/usr/bin/perl

package Processor;
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Job;

sub new {
	my $class = shift;
	my $self = {
		id => shift,
		jobs => [],
		cmax => 0
	};
	
	bless $self, $class;

	return $self;
}

1;
