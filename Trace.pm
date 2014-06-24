#!/usr/bin/perl

package Trace;
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Job;
use Processor;

sub new {
	my $class = shift;
	my $self = {
		file => shift,
		jobs => [],
		status => [],
		partition_count => 0
	};
	
	bless $self, $class;
	return $self;
}

sub read {
	my $self = shift;
	
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

sub print_jobs {
	my $self = shift;
	print join(',', @{$self->{jobs}})."\n";
}

sub print_jobs_time_ratio {
	my $self = shift;
	map {$_->print_time_ratio()} @{$self->{jobs}};
}

sub job {
	my $self = shift;
	my $job_number = shift;

	return $self->{jobs}[$job_number];
}

1;
