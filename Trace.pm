#!/usr/bin/perl

package Trace;
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Job;

sub new {
	my $class = shift;
	my $self = {
		file => shift
	};
	
	bless $self, $class;

	return $self;
}

sub read {
	my $self = shift;
	
	$self->{jobs} = [];
	$self->{status} = [];
	$self->{partition_count} = 0;

	open (FILE, $self->{file});

	while (my $line = <FILE>) {
		my @fields = split(' ', $line);

		next unless defined $fields[0];
	
		# Status line
		if ($fields[0] eq ';') { 
			push $self->{status}, [@fields];
		}	

		# Job line
		elsif ($fields[0] ne ' ') {
			my $job = new Job(@fields);
			push $self->{jobs}, $job;
		}

	}
}

sub print {
	my $self = shift;

	print 'Number of jobs: ' . scalar @{$self->{jobs}} . "\n";
}

sub print_jobs {
	my $self = shift;

	for (my $i = 0; $i < scalar @{$self->{jobs}}; $i++) {
		$self->{jobs}[$i]->print();
	}
}

sub print_jobs_time_ratio {
	my $self = shift;

	for (my $i = 0; $i < scalar @{$self->{jobs}}; $i++) {
		$self->{jobs}[$i]->print_time_ratio();
	}
}

1;
