package ExecutionProfile;

use strict;
use warnings;

use Profile;
use Data::Dumper;

#an execution profile object encodes the set of all profiles of a schedule

sub new {
	my $class = shift;
	my $processors = shift;
	my $self = [ new Profile(0, $processors) ];
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
	my $candidate_processors = $self->[$profile_index]->processors();
	my %left_processors; #processors which might be ok for job
	$left_processors{$_} = $_ for @{$candidate_processors};
	while ($left_duration > 0) {
		my $current_profile = $self->[$profile_index];
		$current_profile->filter_processors(\%left_processors);
		last if (keys %left_processors) == 0; #abort if nothing left
		if (defined $current_profile->duration()) {
			$left_duration -= $current_profile->duration();
			$profile_index++;
		} else {
			last;
		}
	}
	my @available_processors = values %left_processors;
	my @selected_processors = splice @available_processors, 0, $job->requested_cpus();
	return if @selected_processors < $job->requested_cpus();
	return @selected_processors;
}

#precondition : job should be assigned first
sub add_job_at {
	my $self = shift;
	my $start_profile_id = shift;
	my $job = shift;
	my @new_profiles = splice @{$self}, 0, $start_profile_id;
	for my $profile (@{$self}) {
		push @new_profiles, $profile->add_job_if_needed($job);
	}
	@{$self} = @new_profiles;
}

sub starting_time {
	my $self = shift;
	my $profile_index = shift;
	return $self->[$profile_index]->starting_time();
}

sub find_first_profile_for {
	my $self = shift;
	my $job = shift;
	for my $profile_id (0..$#{$self}) {
		my @processors = $self->get_free_processors_for($job, $profile_id);
		return ($profile_id, [@processors]) if @processors;
	}
	die "at least last profile should be ok for job";
}

1;
