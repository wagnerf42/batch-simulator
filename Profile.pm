package Profile;

use ProcessorRange;

use strict;
use warnings;
use overload
	'""' => \&stringification;

use List::Util qw(min);

#a profile objects encodes a set of free processors at a given time

sub new {
	my $class = shift;
	my $self = {};
	$self->{starting_time} = shift;
	my $ids = shift;
	$self->{duration} = shift;
	$self->{processors} = new ProcessorRange($ids);

	bless $self, $class;
	return $self;
}

sub processor_range {
	my $self = shift;
	return $self->{processors};
}

sub stringification {
	my $self = shift;
	my $processors_ids = join(',', $self->{processors}->processors_ids());
	return "[$self->{starting_time} ; ($processors_ids) ; $self->{duration}]" if defined $self->{duration};
	return "[$self->{starting_time} ; ($processors_ids) ]";
}

sub processors_ids {
	my $self = shift;
	return [$self->{processors}->processors_ids()];
}

sub duration {
	my $self = shift;
	$self->{duration} = shift if @_;
	return $self->{duration};
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
	my $middle_profile = new Profile($middle_start, [$self->{processors}->processors_ids()], $middle_duration);
	$middle_profile->remove_used_processors($job);
	push @profiles, $middle_profile;

	if ((not defined $self->ending_time()) or ($job->ending_time() < $self->ending_time())) {
		my $end_duration;
		if (defined $self->{duration}) {
			$end_duration = $self->ending_time() - $job->ending_time();
		}
		my $end_profile = new Profile($job->ending_time(), [$self->{processors}->processors_ids()], $end_duration);
		push @profiles, $end_profile;
	}
	return @profiles;
}

sub is_fully_loaded {
	my $self = shift;
	return $self->{processors}->is_empty();
}

#TODO : remove processors_ids
sub remove_used_processors {
	my $self = shift;
	my $job = shift;
	my %processors_ids_to_remove;
	for my $processor_id (map {$_->id()} @{$job->assigned_processors()}) {
		$processors_ids_to_remove{$processor_id} = 1;
	}
	my @left_processors_ids;
	for my $processor_id ($self->{processors}->processors_ids()) {
		push @left_processors_ids, $processor_id unless exists $processors_ids_to_remove{$processor_id};
	}

	$self->{processors}->processors_ids(\@left_processors_ids);
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
