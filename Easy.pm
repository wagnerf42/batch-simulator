package Easy;
use parent 'Schedule';
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Job;
use Processor;

sub new {
	my $class = shift;
	my $self = {
		trace => shift,
		num_processors => shift,
		processors => [],
		queued_jobs => [],
		profile => []
	};

	for my $id (0..($self->{num_processors} - 1)) {
		my $processor = new Processor($id);
		push $self->{processors}, $processor;
	}

	# The profile needs to start with one item stating that all processors are available on time 0
	my $profile_item = {
		available_cpus => $self->{num_processors},
		starting_time => 0
	};
	push $self->{profile}, $profile_item;

	bless $self, $class;
	return $self;
}

sub assign_job {
	my $self = shift;

	# Queued jobs sorted by expected termination time
	my @queued_jobs = sort {$a->expected_termination_time <=> $b->expected_termination_time} @{$self->{queued_jobs}};
	
	# Find enough space for the next job
	#  

}

1;
