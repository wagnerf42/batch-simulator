package RejectionPolicy;
use strict;
use warnings;

use Job;

sub new {
	my $class = shift;

	my $self = {};

	bless($self, $class);
	return $self;
}

sub should_reject_job {
	my $self = shift;
	my $job = shift;

	return int(rand(10)) == 9;
}

sub should_reject_reservation {
	my $self = shift;
	my $job = shift;
	my $starting_time = shift;
	my $chosen_processors = shift;

	return int(rand(10)) == 9;
}

1;
