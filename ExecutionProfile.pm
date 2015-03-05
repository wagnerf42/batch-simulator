package ExecutionProfile;

use strict;
use warnings;

use List::Util qw(min max);
use Carp;
use Data::Dumper;

use Profile;
use ProcessorRange;
use BinarySearchTree;

use overload '""' => \&stringification;

sub new {
	my $class = shift;
	my $processors_number = shift;
	my $cluster_size = shift;
	my $reduction_algorithm = shift;
	my $starting_time = shift;

	my $self = {
		processors_number => $processors_number,
		cluster_size => $cluster_size,
		reduction_algorithm => $reduction_algorithm
	};

	$self->{profile_tree} = BinarySearchTree->new(-1, 0);
	$self->{profile_tree}->add_content(Profile->new((defined($starting_time) ? $starting_time : 0), [0, $self->{processors_number} - 1]));

	bless $self, $class;
	return $self;
}

sub get_free_processors_for {
	my $self = shift;
	my $job = shift;
	my $starting_time = shift;

	my $left_duration = $job->requested_time();
	my $profile = $self->{profile_tree}->find_content($starting_time);
	my $candidate_processors = $profile->processors();
	my $left_processors = new ProcessorRange($candidate_processors);

	$self->{profile_tree}->nodes_loop($starting_time, undef,
		sub {
			my $profile = shift;
			my $duration = $profile->duration();

			# Stop if we have enough profiles
			return 0 unless $left_duration > 0;

			# Profiles must all be contiguous
			return 0 unless $starting_time == $profile->starting_time();

			$left_processors->intersection($profile->processors());
			return 0 if $left_processors->size() < $job->requested_cpus();

			if (defined $duration) {
				$left_duration -= $duration;
				$starting_time += $duration;
				return 1;
			} else {
				return 0;
			}
		});

	# It is possible that not all processors were found
	return unless $left_processors->size() >= $job->requested_cpus();

	my $reduction_function = $REDUCTION_FUNCTIONS[$self->{reduction_algorithm}];
	$left_processors->$reduction_function($job->requested_cpus());

	return if $left_processors->is_empty();
	die if $left_processors->size() < $job->requested_cpus();

	return $left_processors;
}

sub processors_available_at {
	my $self = shift;
	my $starting_time = shift;
	my $profile = $self->{profile_tree}->find_content($starting_time);
	return $profile->processors()->size() if defined $profile;
	return 0;
}

sub remove_job {
	my $self = shift;
	my $job = shift;
	my $current_time = shift;

	return unless defined $job->starting_time(); #do not remove jobs which are not here anyway

	my $starting_time = $job->starting_time();
	my $job_ending_time = $job->submitted_ending_time();

	my @impacted_profiles;
	$self->{profile_tree}->nodes_loop($starting_time, $job_ending_time,
		sub {
			my $profile = shift;
			push @impacted_profiles, $profile unless $profile->starting_time() == $job_ending_time;
			return 1;
		}
	);

	unless (@impacted_profiles) {
		#we end earlier than expected and all resources were taken
		my $start = max($current_time, $starting_time); #avoid starting in the past
		my $new_profile = Profile->new($start, $job->assigned_processors_ids()->copy_range(), $job_ending_time - $start);
		$self->{profile_tree}->add_content($new_profile);
		return;
	}

	if ($impacted_profiles[0]->starting_time() < $starting_time) {
		#remove
		my $first_profile = shift @impacted_profiles;
		$self->{profile_tree}->remove_content($first_profile);

		#split in two
		my $first_profile_ending_time = $first_profile->ending_time();
		$first_profile->duration($starting_time - $first_profile->starting_time());
		my $second_profile = Profile->new($starting_time, $first_profile->processors()->copy_range(), $first_profile_ending_time - $starting_time);

		#put back
		$self->{profile_tree}->add_content($first_profile);
		$self->{profile_tree}->add_content($second_profile);
		unshift @impacted_profiles, $second_profile;
	}

	if ($impacted_profiles[$#impacted_profiles]->ends_after($job_ending_time)) {
		#remove
		my $first_profile = pop @impacted_profiles;
		$self->{profile_tree}->remove_content($first_profile);

		#split in two
		my $profile_end = $first_profile->ending_time();
		$first_profile->duration($job_ending_time - $first_profile->starting_time());
		my $second_profile;
		my $duration;
		if (defined $profile_end) {
			$duration = $profile_end - $job_ending_time;
		}
		$second_profile = Profile->new($job_ending_time, $first_profile->processors()->copy_range(), $duration);

		#put back
		$self->{profile_tree}->add_content($first_profile);
		$self->{profile_tree}->add_content($second_profile);
		push @impacted_profiles, $first_profile;
	}

	my $previous_profile_ending_time = max($starting_time, $current_time);

	for my $profile (@impacted_profiles) {
		$profile->remove_job($job);
		my $duration = $profile->starting_time() - $previous_profile_ending_time;
		if ($duration > 0) {
			my $new_profile = Profile->new($previous_profile_ending_time, $job->assigned_processors_ids()->copy_range(), $duration);
			$self->{profile_tree}->add_content($new_profile);
		}
		$previous_profile_ending_time = $profile->ending_time();
	}

	return;
}

sub add_job_at {
	my $self = shift;
	my $starting_time = shift;
	my $job = shift;
	my $current_time = shift;

	my @profiles_to_update;
	my $ending_time = $starting_time + $job->requested_time();


	$self->{profile_tree}->nodes_loop($starting_time, $ending_time,
		sub {
			my $profile = shift;
			return 0 if $profile->starting_time == $ending_time; #stop if reaching the last profile
			push @profiles_to_update, $profile;
			return 1;
		});

	#TODO: do things in batch ?
	for my $profile (@profiles_to_update) { 
		$self->{profile_tree}->remove_content($profile);
		my @new_profiles = $profile->add_job($job, $current_time);
		$self->{profile_tree}->add_content($_) for (@new_profiles);
	}

	return;
}

sub could_start_job_at {
	my $self = shift;
	my $job = shift;
	my $starting_time = shift;

	my $min_processors = $job->requested_cpus();
	my $job_ending_time = $starting_time + $job->requested_time();

	$self->{profile_tree}->nodes_loop($starting_time, undef,
		sub {
			my $profile = shift;

			if ($starting_time != $profile->starting_time()) {
				# Gap in the profile, can't use it to run the job
				$min_processors = 0;
				return 0;
			}

			# Ok to return if it's the last profile
			return 0 unless defined $profile->duration();

			$starting_time += $profile->duration();
			$min_processors = min($min_processors, $profile->processors()->size());

			# Ok to return, profile may be good for the job
			return 0 unless $starting_time < $job_ending_time;

			return 0 unless $min_processors >= $job->requested_cpus();
			return 1;
		});

	return $min_processors >= $job->requested_cpus() ? 1 : 0;
}

sub find_first_profile_for {
	my $self = shift;
	my $job = shift;
	my $current_time = shift;

	my $starting_time;
	my $processors;

	$self->{profile_tree}->nodes_loop($current_time, undef,
		sub {
			my $profile = shift;
			if ($self->could_start_job_at($job, $profile->starting_time())) {
				$starting_time = $profile->starting_time();
				$processors = $self->get_free_processors_for($job, $profile->starting_time());
				return 0 if $processors;
			}

			return 1;
		});

	return ($starting_time, $processors) if $processors;
	return;
}

sub set_current_time {
	my $self = shift;
	my $current_time = shift;

	my $updated_profile;
	my @removed_profiles;

	#TODO: change nodes loop prototype to reverse args ?

	$self->{profile_tree}->nodes_loop(undef, $current_time - 1,
		sub {
			my $profile = shift;

			my $starting_time = $profile->starting_time();
			my $ending_time = $profile->ending_time();

			if (defined $ending_time and $ending_time > $current_time) {
				$updated_profile = [$profile, $current_time, $ending_time - $current_time];
				return 0;
			}

			if (not defined $ending_time) {
				$updated_profile = [$profile, $current_time, $profile->duration()];
				return 0;
			}

			push @removed_profiles, $profile;
			return 1;
		});

	if (defined $updated_profile) {
		my ($profile, $starting_time, $duration) = @$updated_profile;
		$self->{profile_tree}->remove_content($profile);
		$profile->starting_time($starting_time);
		$profile->duration($duration);
		$self->{profile_tree}->add_content($profile);
	}

	$self->{profile_tree}->remove_content($_) for @removed_profiles;
	return;
}

sub stringification {
	my $self = shift;
	my @profiles;

	$self->{profile_tree}->nodes_loop(undef, undef,
		sub {
			my $profile = shift;
			push @profiles, $profile;
			return 1;
		});

	return join(', ', @profiles);
}

sub show {
	my $self = shift;

	print STDERR "showing tree:\n";

	$self->{profile_tree}->nodes_loop(undef, undef,
		sub {
			my $profile = shift;
			print STDERR "\tshowing $profile\n";
			return 1;
		});
	return;
}

sub save_svg {
	my ($self, $svg_filename, $time) = @_;
	$time = 0 unless defined $time;

	my @profiles;
	$self->{profile_tree}->nodes_loop(undef, undef, 
		sub {
			my $profile = shift;
			push @profiles, $profile;
			return 1;
		}
	);

	my $last_starting_time = $profiles[$#profiles]->starting_time();
	return if $last_starting_time == 0;

	open(my $filehandle, "> $svg_filename") or die "unable to open $svg_filename";

	print $filehandle "<svg width=\"800\" height=\"600\">\n";
	my $w_ratio = 800/$last_starting_time;
	my $h_ratio = 600/$self->{processors_number};

	# red line at the current time
	my $current_x = $w_ratio * $time;
	print $filehandle "<line x1=\"$current_x\" x2=\"$current_x\" y1=\"0\" y2=\"600\" style=\"stroke:rgb(255,0,0);stroke-width:5\"/>\n";

	for my $profile_index (0..($#profiles-1)) {
		$profiles[$profile_index]->svg($filehandle, $w_ratio, $h_ratio, $time, $profile_index);
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
