package ExecutionProfile;

use strict;
use warnings;

use List::Util qw(min max);

use Data::Dumper;

use Profile;
use ProcessorRange;
use Carp;

use overload '""' => \&stringification;

sub new {
	my ($class, $processors_number, $cluster_size, $reduction_algorithm, $starting_time) = @_;

	my $self = {
		processors_number => $processors_number,
		cluster_size => $cluster_size,
		reduction_algorithm => $reduction_algorithm
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

	my $reduction_function = $REDUCTION_FUNCTIONS[$self->{reduction_algorithm}];
	$left_processors->$reduction_function($job->requested_cpus());

	return if $left_processors->is_empty();
	die if $left_processors->size() < $job->requested_cpus();

	return $left_processors;
}

#returns number of processors available right now
sub processors_available_now {
	my $self = shift;
	my $now_time = shift;
	#now can only be at first profile
	return 0 unless $self->{profiles}->[0]->starting_time() == $now_time;
	return $self->{profiles}->[0]->processors_ids()->size();
}

sub profiles {
	my $self = shift;
	return @{$self->{profiles}};
}

sub remove_job {
	my ($self, $job, $current_time) = @_;
	return unless defined $job->starting_time(); #do not remove jobs which are not here anyway

	# those are the timestamps that will affect profiles
	my $job_starting_time = max($job->starting_time(), $current_time);
	my $job_ending_time = $job->submitted_ending_time();
	my $done_until_time = $job_starting_time;

	#print "\nremove $job between $job_starting_time and $job_ending_time: $self\n";

	my @new_profiles;
	my @impacted_profiles;

	while (my $profile = shift @{$self->{profiles}}) {
		if ((defined $profile->ending_time()) and ($profile->ending_time() <= $job_starting_time)) {
			push @new_profiles, $profile;
		} elsif ($profile->starting_time() >= $job_ending_time) {
			unshift @{$self->{profiles}}, $profile;
			last;
		} else {
			push @impacted_profiles, $profile;
		}
	}

	#print "impacted profiles: @impacted_profiles\n";

	for my $current_profile (@impacted_profiles) {
		my $profile_starting_time = $current_profile->starting_time();
		my $profile_ending_time = $current_profile->ending_time();

		if ($profile_starting_time > $done_until_time) {
			# create a new profile to fill a gap in the execution profile
			push @new_profiles, new Profile($done_until_time, ProcessorRange->new($job->assigned_processors_ids()), $profile_starting_time - $done_until_time);
			$done_until_time = $profile_starting_time;
		}

		if ($profile_starting_time < $job_starting_time) {
			# profile starts before the beginning of the job, so we split it
			push @new_profiles, new Profile($profile_starting_time, ProcessorRange->new($current_profile->processor_range()), $job_starting_time - $profile_starting_time);
			$current_profile->starting_time($job_starting_time);
			$current_profile->duration($profile_ending_time - $job_starting_time);
			$profile_starting_time = $done_until_time;
		}

		if ((defined $profile_ending_time) and ($profile_ending_time <= $job_ending_time)) {
			# profile impacted by the job, update it
			$current_profile->remove_job($job);
			push @new_profiles, $current_profile;
	
		} else {
			# split the profile in 2 for the end of the job
			my $last_profile;
			if (defined $profile_ending_time) {
				$last_profile = new Profile($job_ending_time, ProcessorRange->new($current_profile->processor_range()), $profile_ending_time - $job_ending_time);
			} else {
				$last_profile = new Profile($job_ending_time, ProcessorRange->new($current_profile->processor_range()));
			}
			$current_profile->remove_job($job);
			push @new_profiles, new Profile($profile_starting_time, ProcessorRange->new($current_profile->processor_range()), $job_ending_time - $profile_starting_time);
			push @new_profiles, $last_profile;
		}
		$done_until_time = $profile_ending_time;
	}

	if ($done_until_time < $job_ending_time) {
		push @new_profiles, new Profile($done_until_time, ProcessorRange->new($job->assigned_processors_ids()), $job_ending_time - $done_until_time);
	}

	push @new_profiles, @{$self->{profiles}};
	$self->{profiles} = [@new_profiles];

	#print "after removal: $self\n";
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
	my ($self, $job, $profile_index) = @_;
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
	my ($self, $job, $current_time) = @_;
	my $previous_profile_ending_time = $self->{profiles}->[0]->starting_time();

	for my $profile_id (0..$#{$self->{profiles}}) {
		my $profile_could_be_ok = $self->could_start_job_at($job, $profile_id);
		if ($profile_could_be_ok) {
			my $processors = $self->get_free_processors_for($job, $profile_id);
			return ($profile_id, $processors) if $processors;
		}
		$previous_profile_ending_time = $self->{profiles}->[$profile_id]->ending_time();
	}
	return;
}

sub set_current_time {
	my ($self, $current_time) = @_;

	return if $self->{profiles}->[0]->starting_time() > $current_time;

	my $profile;
	while($profile = shift @{$self->{profiles}}) {
		my $ending_time = $profile->ending_time();

		if (defined $ending_time and $ending_time > $current_time) {
			$profile->starting_time($current_time);
			$profile->duration($ending_time - $current_time);
			last;
		}

		if (not defined $ending_time and $profile->starting_time() < $current_time) {
			$profile->starting_time($current_time);
			last;
		}

		last unless defined $ending_time;
	}

	unshift @{$self->{profiles}}, $profile;
	return;
}

sub stringification {
	my $self = shift;
	return join(', ', @{$self->{profiles}});
}

sub save_svg {
	my ($self, $svg_filename, $time) = @_;
	$time = 0 unless defined $time;

	my $last_starting_time = $self->{profiles}->[$#{$self->{profiles}}]->starting_time();
	return if $last_starting_time == 0;

	open(my $filehandle, "> $svg_filename") or die "unable to open $svg_filename";

	print $filehandle "<svg width=\"800\" height=\"600\">\n";
	my $w_ratio = 800/$last_starting_time;
	my $h_ratio = 600/$self->{processors_number};

	# red line at the current time
	my $current_x = $w_ratio * $time;
	print $filehandle "<line x1=\"$current_x\" x2=\"$current_x\" y1=\"0\" y2=\"600\" style=\"stroke:rgb(255,0,0);stroke-width:5\"/>\n";

	for my $profile_index (0..$#{$self->{profiles}}-1) {
		$self->{profiles}->[$profile_index]->svg($filehandle, $w_ratio, $h_ratio, $time, $profile_index);
	}

	print $filehandle "</svg>\n";
	close $filehandle;
}

my $file_count = 0;
sub tycat {
	my $self = shift;
	my $current_time = shift;
	my $filename = shift;
	#print STDERR "ep tycat $file_count\n";

	my $user = $ENV{"USER"};
	my $dir = "/tmp/$user";
	mkdir $dir unless -f $dir;

	$filename = "$dir/$file_count" . "a.svg" unless defined $filename;
	$self->save_svg($filename, $current_time);
	`tycat $filename` if -f $filename;
	$file_count++;
}

1;
