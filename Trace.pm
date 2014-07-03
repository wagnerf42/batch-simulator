package Trace;
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use List::Util qw(max reduce);

use Job;
use Processor;

sub new {
	my $class = shift;
	my $self = {
		file => shift,
		jobs => [],
		status => [],
		partition_count => 0,
		needed_cpus => 0
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

			if ($job->requested_cpus > $self->{needed_cpus}) {
				$self->{needed_cpus} = $job->requested_cpus;
			}

			push $self->{jobs}, $job;
		}
	}
}

sub requested_cpus {
	my $self = shift;

	return $self->{needed_cpus};
}

sub print_jobs {
	my $self = shift;
	print join(',', @{$self->{jobs}})."\n";
}

sub jobs {
	my $self = shift;

	if (@_) {
		$self->{jobs} = shift;
	}

	return $self->{jobs};
}

1;
