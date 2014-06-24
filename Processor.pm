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

sub get_cmax {
	my $self = shift;

	if (@_) {
		$self->{cmax} = shift;
	}

	return $self->{cmax};
}

sub assign_job {
	my $self = shift;
	my $job = shift;

	push $self->{jobs}, $job;

	$self->{cmax} = $self->{cmax} + $job->{run_time};
}

sub print_jobs {
	my $self = shift;

	print "Jobs for processor with id $self->{id}:\n";
	map {print $_->stringification() . "\n"} @{$self->{jobs}};
}

1;
