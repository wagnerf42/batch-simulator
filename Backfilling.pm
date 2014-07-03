package Backfilling;
use parent 'Schedule';
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Job;
use Processor;

sub new {
	my $class = shift;
	my $self = {
		trace => shift,
		num_processors => shift,
		processors => [],
		queued_jobs => [],
		profile => [],
		backfilled_jobs => 0
	};

	for my $id (0..($self->{num_processors} - 1)) {
		my $processor = new Processor($id);
		push $self->{processors}, $processor;
	}

	# The profile needs to start with one item stating that all processors are available on time 0
	my $profile_item = {
		available_cpus => $self->{num_processors},
		starting_time => 0
	};
	push $self->{profile}, $profile_item;

	bless $self, $class;
	return $self;
}

sub check_availability {
	my $self = shift;
	my $job = shift;
	my $profile = {
		start => -1,
		end => -1,
		new => 0
	};

#	my @profiles = @{$self->{profile}};
#	while (@profiles) {
#		my $start_profile = shift @profiles;
#		my @kept_profiles;
#		for my $profile (@profiles) {
#			push @kept_profiles, $profile;
#
#			last;
#		}
#	}

	for my $i (0..$#{$self->{profile}}) {
		if ($self->{profile}[$i]->{available_cpus} >= $job->requested_cpus) {
			$profile->{start} = $i;

			# Check if there is enough space for the job for the whole duration of the job
			for my $j (($i + 1)..$#{$self->{profile}}) {
				# Not enough space yet and not enough processors
				if (($self->{profile}[$j]->{starting_time} < $self->{profile}[$i]->{starting_time} + $job->run_time) && ($self->{profile}[$j]->{available_cpus} < $job->requested_cpus)) {
					$profile->{start} = -1;
					last;
				}

				# There is enough space with exactly the time necessary
				elsif ($self->{profile}[$j]->{starting_time} == $self->{profile}[$i]->{starting_time} + $job->run_time) {
					$profile->{end} = $j;
					last;
				}

				# There is enough space and must create a new profile item in the middle
				elsif ($self->{profile}[$j]->{starting_time} > $self->{profile}[$i]->{starting_time} + $job->run_time) {
					$profile->{end} = $j;
					$profile->{new} = 1;
					last;
				}
			}

			# Check if there is a non contiguous block of processors available at this time
			my @available_processors = grep {$_->available_at($self->{profile}[$profile->{start}]->{starting_time}, $job->run_time)} @{$self->{processors}};

			if (scalar @available_processors >= $job->requested_cpus) {
				$profile->{selected_processors} = [@available_processors[0..($job->requested_cpus - 1)]];

				# Now we know that the schedule is OK and can increase the
				# number of backfilling jobs if it's the case
				if ($profile->{end} != -1) {
					$self->{backfilled_jobs}++;
				}
				last;
			}

		}
	}
	
	return $profile;
}

sub assign_job {
	my $self = shift;
	my $job = shift;

	my $profile = $self->check_availability($job);

	# Create a new profile item at the end
	if ($profile->{end} == -1) {
		my $profile_item = {
			available_cpus => $self->{num_processors},
			starting_time => $self->{profile}[$profile->{start}]->{starting_time} + $job->run_time
		};

		push $self->{profile}, $profile_item;
		$profile->{end} = @{$self->{profile}} - 1;
	}

	# Create a new profile in the middle
	elsif ($profile->{new} == 1) {
		my $profile_item = {
			available_cpus => $self->{profile}[$profile->{end} - 1]->{available_cpus},
			starting_time => $self->{profile}[$profile->{start}]->{starting_time} + $job->run_time
		};

		splice($self->{profile}, $profile->{end}, 0, $profile_item);
	}

	for my $i ($profile->{start}..($profile->{end} - 1)) {
		$self->{profile}[$i]->{available_cpus} -= $job->requested_cpus;
	}

	$job->starting_time($self->{profile}[$profile->{start}]->{starting_time});
	push $self->{queued_jobs}, $job;

	$job->assign_to($self->{profile}[$profile->{start}]->{starting_time}, $profile->{selected_processors});
}

sub print {
	my $self = shift;

	print "Details for the conservative backfilling: {\n";
	print "\tNumber of backfilled jobs: " . $self->{backfilled_jobs} . "\n";
	print "\tCmax: " . $self->{profile}[$#{$self->{profile}}]->{starting_time} . "\n";
	print "}\n";
}

1;
