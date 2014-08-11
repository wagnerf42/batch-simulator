package ExecutionProfile;

use strict;
use warnings;

use Profile;
use Data::Dumper;
use ProcessorsSet;

#an execution profile object encodes the set of all profiles of a schedule

sub new {
	my ($class, $processors, $cluster_size, $contiguous) = @_;

	my $self = {
		processors => $processors,
		cluster_size => $cluster_size,
		contiguous => $contiguous
	};

	my $ids = [map {$_->id()} @{$self->{processors}}];
	$self->{profiles} = [new Profile(0, $ids)];

	bless $self, $class;
	return $self;
}

sub get_free_processors_for {
	my ($self, $job, $profile_index) = @_;
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

	my @selected_processors = map {$self->{processors}->[$_]} @selected_ids;
	my $processors = new ProcessorsSet(\@selected_processors, scalar @{$self->{processors}}, $self->{cluster_size});

	if ($self->{contiguous}) {
		$processors->reduce_to_cluster_contiguous($job->requested_cpus());
	}

	else {
		$processors->reduce_to_cluster($job->requested_cpus());
	}

	return ([$processors->processors()], $processors->local(), $processors->contiguous()) if $processors->processors();
}

#precondition : job should be assigned first
sub add_job_at {
	my ($self, $job) = @_;
	my @new_profiles;
	for my $profile (@{$self->{profiles}}) {
		push @new_profiles, $profile->add_job_if_needed($job);
	}
	$self->{profiles} = [@new_profiles];
}

sub starting_time {
	my ($self, $profile_index) = @_;
	return $self->{profiles}->[$profile_index]->starting_time();
}

sub find_first_profile_for {
	my ($self, $job) = @_;
	for my $profile_id (0..$#{$self->{profiles}}) {
		my ($processors, $local, $contiguous) = $self->get_free_processors_for($job, $profile_id);
		return ($profile_id, $processors, $local, $contiguous) if $processors;
	}

	die "at least last profile should be ok for job";
}

sub set_current_time {
	my ($self, $current_time) = @_;
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
