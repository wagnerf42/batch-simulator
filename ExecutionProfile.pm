package ExecutionProfile;

use strict;
use warnings;

use base 'Exporter';

use Profile;
use Data::Dumper;
use ProcessorsSet;
use ProcessorRange;
use overload '""' => \&stringification;

use constant EP_BEST_EFFORT => 0;
use constant EP_CLUSTER_CONTIGUOUS => 1;
use constant EP_CONTIGUOUS => 2;
use constant EP_FIRST => 3;
use constant EP_CLUSTER => 4;
use constant EP_BEST_EFFORT_LOCALITY => 5;

our @EXPORT_OK = ('EP_BEST_EFFORT', 'EP_CLUSTER_CONTIGUOUS', 'EP_CONTIGUOUS', 'EP_FIRST', 'EP_CLUSTER', 'EP_BEST_EFFORT_LOCALITY');
our %EXPORT_TAGS = (
	stooges => ['EP_BEST_EFFORT', 'EP_CLUSTER_CONTIGUOUS', 'EP_CONTIGUOUS', 'EP_FIRST', 'EP_CLUSTER', 'EP_BEST_EFFORT_LOCALITY']
);

#an execution profile object encodes the set of all profiles of a schedule

sub new {
	my ($class, $processors_number, $cluster_size, $version) = @_;

	my $self = {
		processors_number => $processors_number,
		cluster_size => $cluster_size,
		version => $version
	};

	$self->{profiles} = [initial Profile(0, 0, $self->{processors_number}-1)];

	bless $self, $class;
	return $self;
}

sub get_free_processors_for {
	my ($self, $job, $profile_index) = @_;
	my $left_duration = $job->run_time();
	my $candidate_processors = $self->{profiles}->[$profile_index]->processors_ids();
	my $left_processors = new ProcessorRange($candidate_processors);
	my $starting_time = $self->{profiles}->[$profile_index]->starting_time();

	while ($left_duration > 0) {
		my $current_profile = $self->{profiles}->[$profile_index];
		return unless $starting_time == $current_profile->starting_time(); #profiles must all be contiguous
		my $duration = $current_profile->duration();
		$starting_time += $duration if defined $duration;
		$left_processors->intersection($current_profile->processor_range());
		return if $left_processors->size() < $job->requested_cpus(); #abort if not enough
		if (defined $current_profile->duration()) {
			$left_duration -= $current_profile->duration();
			$profile_index++;
		} else {
			last;
		}
	}

	if ($self->{version} == EP_BEST_EFFORT) {
		$left_processors->reduce_to_best_effort_contiguous($job->requested_cpus());
	} elsif ($self->{version} == EP_CLUSTER_CONTIGUOUS) {
		$left_processors->reduce_to_cluster_contiguous($job->requested_cpus());
	} elsif ($self->{version} == EP_CONTIGUOUS) {
		$left_processors->reduce_to_forced_contiguous($job->requested_cpus());
	} elsif ($self->{version} == EP_FIRST) {
		$left_processors->reduce_to_first($job->requested_cpus());
	} elsif ($self->{version} == EP_CLUSTER) {
		$left_processors->reduce_to_forced_local($job->requested_cpus(), $self->{cluster_size});
	} elsif ($self->{version} == EP_BEST_EFFORT_LOCALITY) {
		$left_processors->reduce_to_best_effort_local($job->requested_cpus(), $self->{cluster_size});
	}

	return if $left_processors->is_empty();
	die "buggy code" if $left_processors->size() < $job->requested_cpus();
	return $left_processors;
}

#returns the number of profiles impacted by job
sub compute_profiles_impacted_by_job {
	my $self = shift;
	my $job = shift;
	my $in_count = 0;
	for my $profile (@{$self->{profiles}}) {
		last if ($profile->starting_time() >= $job->ending_time());
		$in_count++;
	}
	return $in_count;
}

#precondition : job should be assigned first
sub add_job_at {
	my ($self, $start_profile, $job) = @_;
	my $before = $start_profile; #all these are not impacted by job (starting at 0)
	my @new_profiles = splice @{$self->{profiles}}, 0, $before;

	my $in = $self->compute_profiles_impacted_by_job($job);
	my @impacted_profiles = splice @{$self->{profiles}}, 0, $in;
	for my $profile (@impacted_profiles) {
		push @new_profiles, $profile->add_job($job);
	}
	push @new_profiles, @{$self->{profiles}};
	$self->{profiles} = [@new_profiles];
}

sub starting_time {
	my ($self, $profile_index) = @_;
	return $self->{profiles}->[$profile_index]->starting_time();
}

sub find_first_profile_for {
	my ($self, $job) = @_;
	$starting_index = 0;
	my $min_valid_index;
	for my $profile_id ($starting_index..$#{$self->{profiles}}) {
		if ($self->{profiles}->[$profile_id]->processors_ids()->size() >= $job->requested_cpus()) {
			unless (defined $min_valid_index) {
				$min_valid_index = $profile_id;
			}
			my $processors = $self->get_free_processors_for($job, $profile_id);
			return ($profile_id, $processors) if $processors;
		}
	}

	die "at least last profile should be ok for job";
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
