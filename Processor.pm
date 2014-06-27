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

sub id {
	my $self = shift;

	if (@_) {
		$self->{id} = shift;
	}

	return $self->{id};
}

sub cmax {
	my $self = shift;

	if (@_) {
		$self->{cmax} = shift;
	}

	return $self->{cmax};
}

sub assign_job {
	my $self = shift;
	my $job = shift;
	my $starting_time = shift;

	$job->starting_time($starting_time);
	push $self->{jobs}, $job;

	$self->{cmax} = $starting_time + $job->run_time;
}

sub print_jobs {
	my $self = shift;

	print "Jobs for processor with id $self->{id} and cmax $self->{cmax}:\n";
	map {print $_->stringification() . "\n"} @{$self->{jobs}};
}

sub jobs {
	my $self = shift;

	if (@_) {
		$self->{jobs} = shift;
	}

	return $self->{jobs};
}

1;
