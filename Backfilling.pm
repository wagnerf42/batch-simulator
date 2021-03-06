package Backfilling;
use parent 'Schedule';
use strict;
use warnings;

use Exporter qw(import);
use Time::HiRes qw(time);
use Data::Dumper;
use List::Util qw(min);

use ExecutionProfile;
use Heap;
use Event;
use Util qw(float_equal float_precision);
use Platform;
use Job;

use Debug;

use constant {
	JOB_COMPLETED_EVENT => 0,
	SUBMISSION_EVENT => 1
};

# Creates a new Backfilling object.

# The parameters are redirected to the Schedule class and an execution profile
# is added.
sub new {
	my $class = shift;
	my $reduction_algorithm = shift;

	my $self = $class->SUPER::new(@_);

	$self->{execution_profile} = ExecutionProfile->new(
		$self->{platform}->processors_number(),
		$reduction_algorithm,
	);

	$self->{current_time} = 0;

	# Temporary variables to calculate the average stretch
	$self->{processed_jobs} = 0;
	$self->{total_bounded_stretch} = 0;
	$self->{total_original_bounded_stretch} = 0;

	return $self;
}

sub new_simulation {
	my $class = shift;
	my $reduction_algorithm = shift;

	my $self = $class->SUPER::new_simulation(@_);

	$self->{execution_profile} = ExecutionProfile->new(
		$self->{platform}->processors_number(),
		$reduction_algorithm,
	);

	$self->{current_time} = 0;

	return $self;
}

# Executed the backfilling algorithm.

# The backfilling algorithm uses time based events to detect when jobs are
# submitted or finished.

# It is important to note that from the viewpoint of the algorithm, the actual
# run time of a job is unknown until it starts (i.e. only the submitted run
# time is used). When the job starts, the scheduler will create an ending event
# with the real ending time of the job.

# Also, a particular important part of this implementation of the algorithm is
# the reassignment of jobs. When a job finishes before it's submitted ending
# time, the algorithm tries to reuse that space with jobs that were scheduled
# to start later. For every job that has been submitted but hasn't started yet,
# the algorithm either starts it now using the new space or puts it back in
# it's original position.
sub run {
	my $self = shift;

	$self->{reserved_jobs} = []; # jobs not started yet
	$self->{started_jobs} = {}; # jobs that have already started

	unless ($self->{uses_external_simulator}) {
		$self->{events} = Heap->new(Event->new(SUBMISSION_EVENT, -1));

		$self->{events}->add(
			Event->new(
				SUBMISSION_EVENT,
				$_->submit_time(),
				$_
			)
		) for (@{$self->{trace}->jobs()});
	}

	$self->{run_time} = time(); # time measure

	while (my @events = $self->{events}->retrieve_all()) {
		if ($self->{uses_external_simulator}) {
			$self->{current_time} = $self->{events}->current_time();
		} else {
			# events coming from the heap will have the same time and type
			my $events_timestamp = $events[0]->timestamp();
			$self->{current_time} = $events_timestamp;
		}

		$self->{execution_profile}->set_current_time($self->{current_time});

		my @typed_events;
		push @{$typed_events[$_->type()]}, $_ for @events; # 2 lists, one for each event type

		##DEBUG_BEGIN
		print STDERR "current time: $self->{current_time} events @events\n";
		##DEBUG_END

		# Ending event
		for my $event (@{$typed_events[JOB_COMPLETED_EVENT]}) {

			my $job = $event->payload();

			##DEBUG_BEGIN
			print STDERR "job " . $job->job_number() . " ending\n";
			##DEBUG_END

			delete $self->{started_jobs}->{$job->job_number()};

			if ($self->{uses_external_simulator}) {
				#TODO Revisit the problem that happens when current time is after job ending time
				$self->{execution_profile}->remove_job($job, $self->{current_time});
				$job->run_time($self->{current_time} - $job->starting_time());
			} else {
				$self->{execution_profile}->remove_job($job, $self->{current_time}) unless float_equal($job->requested_time(), $job->run_time());
			}
		}

		# Reassign all reserved jobs if any job finished
		$self->reassign_jobs() if (@{$typed_events[JOB_COMPLETED_EVENT]});

		# Submission events
		for my $event (@{$typed_events[SUBMISSION_EVENT]}) {
			my $job = $event->payload();

			if ($self->{uses_external_simulator}) {
				$job->requested_time($job->requested_time() + $self->{job_delay});
				$job->submit_time($self->{current_time});
				$self->{trace}->add_job($job);
			}

			$self->assign_job($job);
			die "job " . $job->job_number() . " was not assigned" unless defined $job->starting_time();
			push @{$self->{reserved_jobs}}, $job;
		}

		$self->start_jobs();
	}

	# All jobs should be scheduled and started
	die 'there are still jobs in the reserved queue: ' . join(' ', @{$self->{reserved_jobs}}) if @{$self->{reserved_jobs}};

	$self->{execution_profile}->free_profiles();

	# Time measure
	$self->{run_time} = time() - $self->{run_time};

	return;
}

# Tries to start all jobs that have already been submitted.
# When a job can be started, a new ending event is created and pushed into the
# events data structure.

# Note on possible improvement: if jobs in the reserved jobs list are ordered
# by starting time, it may be possible to stop the loop when the first job that
# can't start now is found.
sub start_jobs {
	my $self = shift;
	my @remaining_reserved_jobs;
	my @newly_started_jobs;

	for my $job (@{$self->{reserved_jobs}}) {
		if (float_equal($job->starting_time(), $self->{current_time})) {
			##DEBUG_BEGIN
			print STDERR "job " . $job->job_number() . " starting\n";
			##DEBUG_END

			$self->{events}->add(
				Event->new(
					JOB_COMPLETED_EVENT,
					$job->real_ending_time(),
					$job
				)
			) unless ($self->{uses_external_simulator});

			$self->{started_jobs}->{$job->job_number()} = $job;
			push @newly_started_jobs, $job;
		} else {
			push @remaining_reserved_jobs, $job;
		}
	}

	$self->{reserved_jobs} = \@remaining_reserved_jobs;
	$self->{events}->set_started_jobs(\@newly_started_jobs) if ($self->{uses_external_simulator});

	return;
}

# Tries to reassign all the jobs that have been submitted but haven't started
# yet.

# For each job in the list, the routine checks if the job can start now. If that
# is not possible, the job is returned to it's original position.
sub reassign_jobs {
	my $self = shift;

	for my $job (@{$self->{reserved_jobs}}) {
		if ($self->{execution_profile}->available_processors($self->{current_time}) >= $job->requested_cpus()) {
			my $job_starting_time = $job->starting_time();
			my $assigned_processors = $job->assigned_processors();

			##DEBUG_BEGIN
			print STDERR "enough processors for job " . $job->job_number() . "\n";
			##DEBUG_END

			$self->{execution_profile}->remove_job($job, $self->{current_time});

			my $new_processors;
			if ($self->{execution_profile}->could_start_job($job, $self->{current_time})) {
				##DEBUG_BEGIN
				print STDERR "could start job " . $job->job_number() . "\n";
				##DEBUG_END

				$new_processors = $self->{execution_profile}->get_free_processors($job, $self->{current_time});
			}

			if (defined $new_processors) {
				##DEBUG_BEGIN
				print STDERR "reassigning job " . $job->job_number() . " processors $new_processors\n";
				##DEBUG_END

				$job->assign($self->{current_time}, $new_processors);
				$self->{execution_profile}->add_job($self->{current_time}, $job, $self->{current_time});
			} else {
				$self->{execution_profile}->add_job($job_starting_time, $job, $self->{current_time});
			}
		}
	}

	return;
}

# Finds the first place in the schedule for a job.

# This routine uses the execution profile to find when and on which processors
# the job can be executed. It is then inserted into the list of jobs that have
# been submitted but haven't started yet.
sub assign_job {
	my $self = shift;
	my $job = shift;

	##DEBUG_BEGIN
	print STDERR "assigning job " . $job->job_number() . "\n";
	##DEBUG_END

	my ($starting_time, $chosen_processors) = $self->{execution_profile}->find_first_profile($job);

	##DEBUG_BEGIN
	print STDERR "chose starting time $starting_time and processors $chosen_processors duration " . $job->requested_time() . "\n";
	##DEBUG_END

	# Here we can decide the new run time based on the platform level
	my $job_platform_level = $self->{platform}->job_level_distance($chosen_processors);
	my $new_job_run_time = $job->run_time() * $self->{platform}->speedup($job_platform_level - 1);

	if ($new_job_run_time > $job->requested_time()) {
		$job->run_time($job->requested_time());
		$job->status(JOB_STATUS_FAILED);
	}

	else {
		$job->run_time($new_job_run_time);
	}

	$job->assign($starting_time, $chosen_processors);
	$self->{execution_profile}->add_job($starting_time, $job);

	return;
}

1;
