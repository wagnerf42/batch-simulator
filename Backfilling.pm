package Backfilling;
use parent 'Schedule';
use strict;
use warnings;

use Carp;
use Exporter qw(import);
use Time::HiRes qw(time);

use ExecutionProfile;
use Heap;
use Event;

use constant {
	JOB_COMPLETED_EVENT => 0,
	SUBMISSION_EVENT => 1
};

use constant {
	BASIC => 0,
	BEST_EFFORT_CONTIGUOUS => 1,
	CONTIGUOUS => 2,
	BEST_EFFORT_LOCAL => 3,
	LOCAL => 4
};

our @EXPORT = qw(BASIC BEST_EFFORT_CONTIGUOUS CONTIGUOUS BEST_EFFORT_LOCAL LOCAL NEW_EXECUTION_PROFILE REUSE_EXECUTION_PROFILE);

=head1 NAME

Backfilling - Implementation of the Backfilling algorithm

=head2 METHODS

=over 12

=item new(trace, num_processors, cluster_size, reduction_algorithm)

Creates a new Backfilling object.

The parameters are redirected to the Schedule class and an execution profile is
added.

=cut

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	$self->{execution_profile} = ExecutionProfile->new($self->{num_processors}, $self->{cluster_size}, $self->{reduction_algorithm});
	return $self;
}

=item run()

Executed the backfilling algorithm.

The backfilling algorithm uses time based events to detect when jobs are
submitted or finished.

It is important to note that from the viewpoint of the algorithm, the actual
run time of a job is unknown until it starts (i.e. only the submitted run time
is used). When the job starts, the scheduler will create an ending event with
the real ending time of the job.

Also, a particular important part of this implementation of the algorithm is
the reassignment of jobs. When a job finishes before it's submitted ending
time, the algorithm tries to reuse that space with jobs that were scheduled to
start later. For every job that has been submitted but hasn't started yet, the
algorithm either starts it now using the new space or puts it back in it's
original position.

=cut

sub run {
	my $self = shift;

	# Jobs not started yet
	$self->{reserved_jobs} = [];

	# Jobs which started before current time
	$self->{started_jobs} = {};
	unless ($self->uses_external_simulator()) {
		#we have a trace file, add all corresponding events
		$self->{events} = Heap->new(Event->new(SUBMISSION_EVENT, -1));
		# Add all jobs to the queue
		$self->{events}->add(Event->new(SUBMISSION_EVENT, $_->submit_time(), $_)) for (@{$self->{trace}->jobs()});
	}

	# Time measure
	$self->{schedule_time} = time();

	while ($self->{events}->not_empty()) {
		# Events coming from the Heap will have same timestamp and type
		my @events = $self->{events}->retrieve_all();

		if ($self->uses_external_simulator()) {
			$self->{current_time} = $self->{events}->current_time();
		} else {
			my $events_timestamp = $events[0]->timestamp();
			$self->{current_time} = $events_timestamp;
		}
		$self->{execution_profile}->set_current_time($self->{current_time});

		my @typed_events;
		push @{$typed_events[$_->type()]}, $_ for @events;

		#first process all jobs ending events
		for my $event (@{$typed_events[JOB_COMPLETED_EVENT]}) {
			my $job = $event->payload();
			delete $self->{started_jobs}->{$job->job_number()};
			$self->{execution_profile}->remove_job($job, $self->{current_time}) if ($job->requested_time() != $job->run_time());
		}

		if (@{$typed_events[JOB_COMPLETED_EVENT]}) {
			$self->reassign_jobs_two_positions();
		}

		#then all submissions events
		for my $event (@{$typed_events[SUBMISSION_EVENT]}) {
			my $job = $event->payload();
			$self->assign_job($job);
			die "job $job is not assigned" unless defined $job->starting_time();
			push @{$self->{reserved_jobs}}, $job;
		}

		$self->start_jobs();
	}

	# Time measure
	$self->{schedule_time} = time() - $self->{schedule_time};
	return;
}

=item start_jobs()

Tries to start all jobs that have already been submitted.

When a job can be started, a new ending event is created and pushed into the
events data structure.

Note on possible improvement: if jobs in the reserved jobs list are ordered by
starting time, it may be possible to stop the loop when the first job that
can't start now is found.

=cut

sub start_jobs {
	my $self = shift;
	my @remaining_reserved_jobs;

	my @newly_started_jobs;
	for my $job (@{$self->{reserved_jobs}}) {
		if ($job->starting_time() == $self->{current_time}) {
			unless ($self->uses_external_simulator()) {
				$self->{events}->add(Event->new(JOB_COMPLETED_EVENT, $job->real_ending_time(), $job));
			}
			$self->{started_jobs}->{$job->job_number()} = $job;
			push @newly_started_jobs, $job;
		} else {
			push @remaining_reserved_jobs, $job;
		}
	}

	$self->{reserved_jobs} = \@remaining_reserved_jobs;
	if ($self->uses_external_simulator()) {
		$self->{events}->set_started_jobs(\@newly_started_jobs);
	}
	return;
}

=item reassign_jobs_two_positions()

Tries to reassign all the jobs that have been submitted but haven't started
yet.

For each job in the list, the routine checks if the job can start now. If that
is not possible, the job is returned to it's original position.

=cut

sub reassign_jobs_two_positions {
	my $self = shift;

	for my $job (@{$self->{reserved_jobs}}) {
		if ($self->{execution_profile}->processors_available_at($self->{current_time}) >= $job->requested_cpus()) {
			my $job_starting_time = $job->starting_time();
			my $assigned_processors = $job->assigned_processors_ids();

			$self->{execution_profile}->remove_job($job, $self->{current_time});

			my $new_processors;
			if ($self->{execution_profile}->could_start_job_at($job, $self->{current_time})) {
				$new_processors = $self->{execution_profile}->get_free_processors_for($job, $self->{current_time});
			}

			if ($new_processors) {
				$job->assign_to($self->{current_time}, $new_processors);
				$self->{execution_profile}->add_job_at($self->{current_time}, $job, $self->{current_time});
			} else {
				$self->{execution_profile}->add_job_at($job_starting_time, $job, $self->{current_time});
			}
		}
	}
	return;
}

=item assign_job(job)

Finds the first place in the schedule for a job.

This routine uses the execution profile to find when and on which processors
the job can be executed. It is then inserted into the list of jobs that have
been submitted but haven't started yet.

=cut

sub assign_job {
	my $self = shift;
	my $job = shift;

	my ($starting_time, $chosen_processors) = $self->{execution_profile}->find_first_profile_for($job);
	$job->assign_to($starting_time, $chosen_processors);
	$self->{execution_profile}->add_job_at($starting_time, $job, $self->{current_time});

	return;
}

1;
