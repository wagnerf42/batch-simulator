package Profile;

use strict;
use warnings;
use overload
	'""' => \&stringification;

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
	die "job starts after me" if $self->{starting_time} < $job->starting_time();
	#job is ok, two cases : if it ends before ourselves or not
	my @profiles;
	if ((not (defined $self->{duration})) or ($self->{starting_time} + $self->{duration} > $job->ending_time())) {
		#split
		push @profiles, $self->split($job);
	} else {
		#do not split
		push @profiles, $self;
	}
	$profiles[0]->remove_used_processors($job); #remove processors only for starting profile where job executes
	shift @profiles if $profiles[0]->is_fully_loaded();
	return @profiles;
}

#precondition: jobs splits the profile
sub split {
	my $self = shift;
	my $job = shift;
	my $start_profile = new Profile($self->{starting_time}, $self->{processors}, $job->ending_time()-$self->{starting_time});
	my $end_duration;
	if (defined $self->{duration}) {
		$end_duration = $self->{starting_time} + $self->{duration} - $job->ending_time();
		die "pb" if $end_duration <= 0;
	}
	my $end_profile = new Profile($job->ending_time(), $self->{processors}, $end_duration);
	return ($start_profile, $end_profile);
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
	return $self->{starting_time};
}

1;
