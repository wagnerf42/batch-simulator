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

	$self->{profile_tree} = BinarySearchTree->new(Profile->initial((defined($starting_time) ? $starting_time : 0), 0, $self->{processors_number} - 1));

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

			# Stop if we have enough profiles
			return 0 unless $left_duration > 0;

			# Profiles must all be contiguous
			return 0 unless $starting_time == $profile->starting_time();

			my $duration = $profile->duration();
			$starting_time += $duration if defined $duration;

			$left_processors->intersection($profile->processors());
			return if $left_processors->size() < $job->requested_cpus();

			if (defined $profile->duration()) {
				$left_duration -= $profile->duration();
				return 1;
			} else {
				return 0;
			}
		});

	# It is possible that not all processors were found
	return unless $left_processors->size() == $job->requested_cpus();

	my $reduction_function = $REDUCTION_FUNCTIONS[$self->{reduction_algorithm}];
	$left_processors->$reduction_function($job->requested_cpus());

	return if $left_processors->is_empty();
	die if $left_processors->size() < $job->requested_cpus();

	return $left_processors;
}

sub processors_available_at {
	my $self = shift;
	my $starting_time = shift;
	my $profile = $self->{profile_tree}->find_node($starting_time);
	return $profile->processors()->size();
}

sub remove_job {
	my $self = shift;
	my $job = shift;
	my $current_time = shift;

	return unless defined $job->starting_time(); #do not remove jobs which are not here anyway

	# those are the timestamps that will affect profiles
	my $job_starting_time = max($job->starting_time(), $current_time);
	my $job_ending_time = $job->submitted_ending_time();
	my $done_until_time = $job_starting_time;

	#print "\nremove $job between $job_starting_time and $job_ending_time: $self\n";

	# It is more complicated than this, compare with previous code
	$self->{profile_tree}->nodes_loop($job_starting_time, $job_ending_time,
		sub {
			my $profile = shift;

			my $profile_starting_time = $profile->starting_time();
			my $profile_ending_time = $profile->ending_time();

			if ($profile_starting_time > $done_until_time) {
				# Gap in the profile: create a new one
				$self->{profile_tree}->add(new Profile($done_until_time, ProcessorRange->new($job->assigned_processors_ids()), $profile_starting_time - $done_until_time));
				$done_until_time = $profile_starting_time;

			} elsif ($profile_starting_time < $job->starting_time()) {
				# Profile starts before the beginning of the job
				# This will never happen with this implementation
				$self->{profile_tree}->add(new Profile($profile_starting_time, ProcessorRange->new($profile->processor_range()), $job_starting_time - $profile_starting_time));
				$profile->starting_time($job_starting_time);
				$profile->duration($profile_ending_time - $job_starting_time);
				$profile_starting_time = $done_until_time;
			}

			if (defined $profile_ending_time and $profile_ending_time <= $job_ending_time) {
				# Update profile
				$profile->remove_job($job);

			} else {
				# Split profile in 2 at the end of the job
				if (defined $profile_ending_time) {
					$self->{profile_tree}->add(new Profile($job_ending_time, ProcessorRange->new($profile->processor_range()), $profile_ending_time - $job_ending_time));
				} else {
					$self->{profile_tree}->add(new Profile($job_ending_time, ProcessorRange->new($profile->processor_range())));
				}

				$self->{profile_tree}->add(new Profile($profile_starting_time, ProcessorRange->new($profile->processor_range()), $job_ending_time - $profile_starting_time));
				$done_until_time = $profile_ending_time;

				# Problem: the old code "forgets" about the current profile, in this case we would to remove it from the tree now
			}

			return 1;
		});


	if ($done_until_time < $job_ending_time) {
		$self->{profile_tree}->add(new Profile($done_until_time, ProcessorRange->new($job->assigned_processors_ids()), $job_ending_time - $done_until_time));
	}

	return;
}

sub add_job_at {
	my $self = shift;
	my $starting_time = shift;
	my $job = shift;
	my $current_time = shift;

	$self->{profile_tree}->nodes_loop($starting_time, $starting_time + $job->requested_time(),
		sub {
			my $profile = shift;
			$profile->add_job($job, $current_time);
			return 1;
		});

	return;
}

sub starting_time {
	my $self = shift;
	my $starting_time = shift;
	my $profile = $self->{profile_tree}->find_node($starting_time);
	return $profile->starting_time();
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
	my $processors;

	$self->{profile_tree}->nodes_loop($current_time, undef,
		sub {
			my $profile = shift;
			if ($self->could_start_job_at($job, $profile->starting_time())) {
				$processors = $self->get_free_processors_for($job, $profile->starting_time());
				return 0 if $processors;
			}

			return 1;
		});

	return $processors if $processors;
	return;
}

sub set_current_time {
	my $self = shift;
	my $current_time = shift;

	$self->{profile_tree}->nodes_loop($current_time, undef,
		sub {
			my $profile = shift;
			my $starting_time = $profile->starting_time();
			my $ending_time = $profile->ending_time();

			return 0 if $starting_time > $current_time;

			if (defined $ending_time and $ending_time > $current_time) {
				$profile->starting_time($current_time);
				$profile->duration($ending_time - $current_time);
				return 0;
			}

			if (not defined $ending_time and $starting_time < $current_time) {
				$profile->starting_time($current_time);
				return 0;
			}

			return 0 unless defined $ending_time;
			return 1;
		});

	return;
}

#NOTE fernando: I stopped here

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
