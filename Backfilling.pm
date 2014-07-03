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

	my $profile_helper = {
		first => -1,
		last => -1,
		new => 0
	};

	for my $i (0..$#{$self->{profile}}) {
		if ($self->{profile}[$i]->{available_cpus} >= $job->requested_cpus) {
			$profile_helper->{first} = $i;

			# Check if there is enough space for the job for the whole duration of the job
			for my $j (($i + 1)..$#{$self->{profile}}) {
				# Not enough space yet and not enough processors
				if (($self->{profile}[$j]->{starting_time} < $self->{profile}[$i]->{starting_time} + $job->run_time) && ($self->{profile}[$j]->{available_cpus} < $job->requested_cpus)) {
					$profile_helper->{first} = -1;
					last;
				}

				# There is enough space with exactly the time necessary
				elsif ($self->{profile}[$j]->{starting_time} == $self->{profile}[$i]->{starting_time} + $job->run_time) {
					$profile_helper->{last} = $j;
					last;
				}

				# There is enough space and must create a new profile item in the middle
				elsif ($self->{profile}[$j]->{starting_time} > $self->{profile}[$i]->{starting_time} + $job->run_time) {
					$profile_helper->{last} = $j;
					$profile_helper->{new} = 1;
					last;
				}
			}

			# Check if there is a non contiguous block of processors available at this time
			my @available_processors = grep {$_->available_at($self->{profile}[$profile_helper->{first}]->{starting_time}, $job->run_time)} @{$self->{processors}};

			if (scalar @available_processors >= $job->requested_cpus) {
				$profile_helper->{selected_processors} = [@available_processors[0..($job->requested_cpus - 1)]];

				# Now we know that the schedule is OK and can increase the
				# number of backfilling jobs if it's the case
				if ($profile_helper->{last} != -1) {
					$self->{backfilled_jobs}++;
				}
				last;
			}
		}
	}

	return $profile_helper;
}

sub assign_job {
	my $self = shift;
	my $job = shift;

	my $profile_helper = $self->check_availability($job);

	# Create a new profile item at the end
	if ($profile_helper->{last} == -1) {
		my $profile_item = {
			available_cpus => $self->{num_processors},
			starting_time => $self->{profile}[$profile_helper->{first}]->{starting_time} + $job->run_time
		};

		push $self->{profile}, $profile_item;
		$profile_helper->{last} = @{$self->{profile}} - 1;
	}

	# Create a new profile in the middle
	elsif ($profile_helper->{new} == 1) {
		my $new_profile_item = {
			available_cpus => $self->{profile}[$profile_helper->{last} - 1]->{available_cpus},
			starting_time => $self->{profile}[$profile_helper->{first}]->{starting_time} + $job->run_time
		};

		splice($self->{profile}, $profile_helper->{last}, 0, $new_profile_item );
	}

	for my $i ($profile_helper->{first}..($profile_helper->{last} - 1)) {
		$self->{profile}[$i]->{available_cpus} -= $job->requested_cpus;
	}

	$job->starting_time($self->{profile}[$profile_helper->{first}]->{starting_time});
	push $self->{queued_jobs}, $job;

	$job->assign_to($self->{profile}[$profile_helper->{first}]->{starting_time}, $profile_helper->{selected_processors});
}

sub print {
	my $self = shift;

	print "Details for the conservative backfilling: {\n";
	print "\tNumber of backfilled jobs: " . $self->{backfilled_jobs} . "\n";
	print "\tCmax: " . $self->{profile}[$#{$self->{profile}}]->{starting_time} . "\n";
	print "}\n";
}

1;
