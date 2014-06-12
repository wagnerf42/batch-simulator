#!/usr/bin/perl

package Trace;
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Job;

	
my $partitions_count = 0;

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

			next unless defined $fields[1];

			if ($fields[1] eq 'Partition:') {
				$self->{partition_count}++;
			}

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
}

1;
