package ExecutionProfile;

use strict;
use warnings;

use Profile;
use Data::Dumper;
use ProcessorsSet;

#an execution profile object encodes the set of all profiles of a schedule

sub new {
	my $class = shift;
	my $self = {
		processors => shift,
		contiguous => shift
	};

	my $ids = [map {$_->id()} @{$self->{processors}}];
	$self->{profiles} = [ new Profile(0, $ids) ];

	bless $self, $class;
	return $self;
}

#given a job we want to start at a given profile
#return list of processors or nothing if not possible
sub get_free_processors_for {
	my $self = shift;
	my $job = shift;
	my $profile_index = shift;
	my $left_duration = $job->run_time();
	my $candidate_processors = $self->{profiles}->[$profile_index]->processors_ids();
	my %left_processors; #processors which might be ok for job
	$left_processors{$_} = $_ for @{$candidate_processors};
	my $starting_time = $self->{profiles}->[$profile_index]->starting_time();

	while ($left_duration > 0) {
		my $current_profile = $self->{profiles}->[$profile_index];
		return unless $starting_time == $current_profile->starting_time(); #profiles must all be contiguous
		my $duration = $current_profile->duration();
		$starting_time += $duration if defined $duration;
		$current_profile->filter_processors_ids(\%left_processors);
		last if (keys %left_processors) == 0; #abort if nothing left
		if (defined $current_profile->duration()) {
			$left_duration -= $current_profile->duration();
			$profile_index++;
		} else {
			last;
		}
	}
	my @selected_ids = values %left_processors;
	return unless @selected_ids >= $job->requested_cpus();
	my $processors = new ProcessorsSet(map {$self->{processors}->[$_]} @selected_ids);

#	if ($self->{contiguous}) {
#		$processors->reduce_to_contiguous($job->requested_cpus());
#	} else {
#		$processors->reduce_to($job->requested_cpus());
#	}
	$processors->reduce_to_contiguous($job->requested_cpus());
	#$processors->reduce_to($job->requested_cpus());

	return $processors->processors();
}

#precondition : job should be assigned first
sub add_job_at {
	my $self = shift;
	my $job = shift;
	my @new_profiles;
	for my $profile (@{$self->{profiles}}) {
		push @new_profiles, $profile->add_job_if_needed($job);
	}
	$self->{profiles} = [@new_profiles];
}

sub starting_time {
	my $self = shift;
	my $profile_index = shift;
	return $self->{profiles}->[$profile_index]->starting_time();
}

sub find_first_profile_for {
	my $self = shift;
	my $job = shift;
	for my $profile_id (0..$#{$self->{profiles}}) {
		my @processors = $self->get_free_processors_for($job, $profile_id);
		return ($profile_id, [@processors]) if @processors;
	}

	die "at least last profile should be ok for job";
}

sub set_current_time {
	my $self = shift;
	my $current_time = shift;

	my @remaining_profiles;

	for my $profile (@{$self->{profiles}}) {
		if ($profile->starting_time() >= $current_time) {
			push @remaining_profiles, $profile;
		}

		elsif ((not defined $profile->ending_time()) or ($profile->ending_time() > $current_time)) {
			my $ending_time = $profile->ending_time();
			$profile->starting_time($current_time);
			if (defined $ending_time) {
				my $new_duration = $ending_time - $current_time;
				$profile->duration($new_duration);
			}
			push @remaining_profiles, $profile;
		}
	}

	$self->{profiles} = [@remaining_profiles];
}

1;
