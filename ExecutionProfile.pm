package ExecutionProfile;

use strict;
use warnings;

use Data::Dumper;

use Profile;
use ProcessorRange;

use overload '""' => \&stringification;

sub new {
	my ($class, $processors_number, $cluster_size, $version, $starting_time) = @_;

	my $self = {
		processors_number => $processors_number,
		cluster_size => $cluster_size,
		version => $version
	};

	$self->{profiles} = [initial Profile((defined($starting_time) ? $starting_time : 0), 0, $self->{processors_number}-1)];

	bless $self, $class;
	return $self;
}

sub get_free_processors_for {
	my ($self, $job, $profile_index) = @_;

	my $left_duration = $job->requested_time();
	my $candidate_processors = $self->{profiles}->[$profile_index]->processors_ids();
	my $left_processors = new ProcessorRange($candidate_processors);
	my $starting_time = $self->{profiles}->[$profile_index]->starting_time();

	while ($left_duration > 0) {
		my $current_profile = $self->{profiles}->[$profile_index];

		# Profiles must all be contiguous
		return unless $starting_time == $current_profile->starting_time();

		my $duration = $current_profile->duration();
		$starting_time += $duration if defined $duration;

		$left_processors->intersection($current_profile->processor_range());
		return if $left_processors->size() < $job->requested_cpus();

		if (defined $current_profile->duration()) {
			$left_duration -= $current_profile->duration();
			$profile_index++;
		} else {
			last;
		}
	}

	my $reduction_function = $REDUCTION_FUNCTIONS[$self->{version}];
	$left_processors->$reduction_function($job->requested_cpus());

	return if $left_processors->is_empty();
	die if $left_processors->size() < $job->requested_cpus();

	return $left_processors;
}

sub compute_profiles_impacted_by_job {
	my ($self, $job, $current_time) = @_;
	my $in_count = 0;

	for my $profile (@{$self->{profiles}}) {
		last if ($profile->starting_time() >= $job->ending_time_estimation($current_time));
		$in_count++;
	}
	return $in_count;
}

sub add_job_at {
	my ($self, $start_profile, $job, $current_time) = @_;
	my $before = $start_profile; #all these are not impacted by job (starting at 0)
	my @new_profiles = splice @{$self->{profiles}}, 0, $before;
	my $in = $self->compute_profiles_impacted_by_job($job, $current_time);
	my @impacted_profiles = splice @{$self->{profiles}}, 0, $in;

	for my $profile (@impacted_profiles) {
		push @new_profiles, $profile->add_job($job, $current_time);
	}

	push @new_profiles, @{$self->{profiles}};
	$self->{profiles} = [@new_profiles];
}

sub starting_time {
	my ($self, $profile_index) = @_;
	return $self->{profiles}->[$profile_index]->starting_time();
}

#TODO There is code duplication with get_free_processors_for
sub could_start_job_at {
	my $self = shift;
	my $job = shift;
	my $profile_index = shift;
	my $min_processors = $self->{profiles}->[$profile_index]->processor_range()->size();
	return 0 unless $min_processors >= $job->requested_cpus();
	my $left_duration = $job->run_time();
	my $starting_time = $self->{profiles}->[$profile_index]->starting_time();

	while ($left_duration > 0) {
		my $current_profile = $self->{profiles}->[$profile_index];
		return 0 unless $starting_time == $current_profile->starting_time(); #profiles must all be contiguous
		my $duration = $current_profile->duration();
		$starting_time += $duration if defined $duration;
		my $current_processors = $current_profile->processor_range()->size();
		$min_processors = $current_processors if $current_processors < $min_processors;
		return 0 unless $min_processors >= $job->requested_cpus();
		if (defined $duration) {
			$left_duration -= $duration;
			$profile_index++;
		} else {
			last;
		}
	}
	return 1;

}

sub find_first_profile_for {
	my ($self, $job) = @_;
	my $starting_index = 0;
	for my $profile_id ($starting_index..$#{$self->{profiles}}) {
		if ($self->could_start_job_at($job, $profile_id)) {
			my $processors = $self->get_free_processors_for($job, $profile_id);
			return ($profile_id, $processors) if $processors;
		}
	}

	die 'at least the last profile should be ok for job';
}

sub set_current_time {
	my ($self, $current_time) = @_;
	return if $self->{profiles}->[0]->starting_time() >= $current_time;
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

sub stringification {
	my $self = shift;
	return join(', ', @{$self->{profiles}});
}

1;
