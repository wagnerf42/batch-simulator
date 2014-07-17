package Profile;

use strict;
use warnings;
use overload
	'""' => \&stringification;

use List::Util qw(min);

#a profile objects encodes a set of free processors at a given time

sub new {
	my $class = shift;
	my $self = {
		starting_time => shift,
		processors => shift,
		duration => shift
	};

	bless $self, $class;
	return $self;
}

sub stringification {
	my $self = shift;
	my $processors = join(',', @{$self->{processors}});
	return "[$self->{starting_time} ; ($processors) ; $self->{duration}]" if defined $self->{duration};
	return "[$self->{starting_time} ; ($processors) ]";
}

sub processors {
	my $self = shift;
	return $self->{processors};
}

sub duration {
	my $self = shift;
	$self->{duration} = shift if @_;
	return $self->{duration};
}

#given a hash of processors, remove all processors
#which are not in profile from this hash
sub filter_processors {
	my $self = shift;
	my $href = shift;
	my %processors;
	for my $processor (@{$self->{processors}}) {
		$processors{$processor} = 1;
	}
	for my $key (keys %{$href}) {
		delete $href->{$key} unless exists $processors{$key};
	}
}

#returns two or one profile if it is split or not by job insertion
sub add_job_if_needed {
	my $self = shift;
	my $job = shift;
	return $self if $self->{starting_time} >= $job->ending_time();
	return $self if defined $self->ending_time() and $self->ending_time() <= $job->starting_time();
	if ($self->starting_time() < $job->starting_time()) {
		my $new_end;
		if (defined $self->{duration}) {
			$new_end = min($self->ending_time(), $job->starting_time());
		} else {
			$new_end = $job->starting_time();
		}
		$self->{duration} = $new_end - $self->{starting_time};
	}
	return $self->split($job);
}

sub split {
	my $self = shift;
	my $job = shift;

	my @profiles;
	my $middle_start = $self->{starting_time};
	my $middle_end;
	if (defined $self->{duration}) {
		$middle_end = min($self->ending_time(), $job->ending_time());
	} else {
		$middle_end = $job->ending_time();
	}
	my $middle_duration = $middle_end - $middle_start if defined $middle_end;
	my $middle_profile = new Profile($middle_start, $self->{processors}, $middle_duration);
	$middle_profile->remove_used_processors($job);
	push @profiles, $middle_profile;

	if ((not defined $self->ending_time()) or ($job->ending_time() < $self->ending_time())) {
		my $end_duration;
		if (defined $self->{duration}) {
			$end_duration = $self->ending_time() - $job->ending_time();
		}
		my $end_profile = new Profile($job->ending_time(), $self->{processors}, $end_duration);
		push @profiles, $end_profile;
	}
	return @profiles;
}

sub is_fully_loaded {
	my $self = shift;
	return (@{$self->{processors}} == 0);
}

sub remove_used_processors {
	my $self = shift;
	my $job = shift;
	my %processors_to_remove;
	for my $processor (@{$job->assigned_processors()}) {
		$processors_to_remove{$processor} = 1;
	}
	my @left_processors;
	for my $processor (@{$self->{processors}}) {
		push @left_processors, $processor unless exists $processors_to_remove{$processor};
	}
	$self->{processors} = [@left_processors];
}

sub starting_time {
	my $self = shift;

	$self->{starting_time} = shift if @_;
	return $self->{starting_time};
}

sub ending_time {
	my $self = shift;

	return unless defined $self->{duration};
	return $self->{starting_time} + $self->{duration};
}

1;
