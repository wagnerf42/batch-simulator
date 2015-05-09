package Backfilling;
use parent 'Schedule';
use strict;
use warnings;

use Exporter qw(import);
use Time::HiRes qw(time);
use Log::Log4perl qw(get_logger :no_extra_logdie_message);

use ExecutionProfile;
use Heap;
use Event;
use Util qw(float_equal float_precision);
use Debug;

use constant {
	JOB_COMPLETED_EVENT => 0,
	SUBMISSION_EVENT => 1
};

use constant {
	BASIC => 0,
	BEST_EFFORT_CONTIGUOUS => 1,
	CONTIGUOUS => 2,
	BEST_EFFORT_LOCAL => 3,
	LOCAL => 4,
};

our @BACKFILLING_VARIANT_STRINGS = (
	"BASIC",
	"BEST_EFFORT_CONTIGUOUS",
	"CONTIGUOUS",
	"BEST_EFFORT_LOCAL",
	"LOCAL",
);

our @EXPORT = qw(BASIC BEST_EFFORT_CONTIGUOUS CONTIGUOUS BEST_EFFORT_LOCAL LOCAL @BACKFILLING_VARIANT_STRINGS NEW_EXECUTION_PROFILE REUSE_EXECUTION_PROFILE);

=head1 NAME

Backfilling - Implementation of the Backfilling algorithm

=head2 METHODS

=over 12

=item new(trace, processors_number, cluster_size, reduction_algorithm)

Creates a new Backfilling object.

The parameters are redirected to the Schedule class and an execution profile is
added.

=cut

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	$self->{execution_profile} = ExecutionProfile->new($self->{processors_number}, $self->{cluster_size}, $self->{reduction_algorithm});
	$self->{current_time} = 0;

	return $self;
}

sub new_simulation {
	my $class = shift;
	my $self = $class->SUPER::new_simulation(@_);

	$self->{execution_profile} = ExecutionProfile->new($self->{processors_number}, $self->{cluster_size}, $self->{reduction_algorithm});
	$self->{current_time} = 0;

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
	my $logger = get_logger('Backfilling::run');

	$self->{reserved_jobs} = []; # jobs not started yet
	$self->{started_jobs} = {}; # jobs that have already started

	unless ($self->{uses_external_simulator}) {
		$self->{events} = Heap->new(Event->new(SUBMISSION_EVENT, -1));
		$self->{events}->add(Event->new(SUBMISSION_EVENT, $_->submit_time(), $_)) for (@{$self->{trace}->jobs()});
	}

	$self->{run_time} = time(); # time measure

	while (my @events = $self->{events}->retrieve_all()) {
		if ($self->{uses_external_simulator}) {
			$self->{current_time} = $self->{events}->current_time();
		} else {
			my $events_timestamp = $events[0]->timestamp(); # events coming from the heap will have the same time and type
			$self->{current_time} = $events_timestamp;
		}

		$self->{execution_profile}->set_current_time($self->{current_time});

		my @typed_events;
		push @{$typed_events[$_->type()]}, $_ for @events; # 2 lists, one for each event type

		##DEBUG_BEGIN
		$logger->debug("current time: $self->{current_time} events @events");
		##DEBUG_END

		# Ending event
		for my $event (@{$typed_events[JOB_COMPLETED_EVENT]}) {
			my $job = $event->payload();

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
		$self->reassign_jobs_two_positions() if (@{$typed_events[JOB_COMPLETED_EVENT]});

		# Submission events
		for my $event (@{$typed_events[SUBMISSION_EVENT]}) {
			my $job = $event->payload();

			if ($self->{uses_external_simulator}) {
				$job->requested_time($job->requested_time() + $self->{job_delay});
				$self->{trace}->add_job($job);
			}

			$self->assign_job($job);
			$logger->logdie("job " . $job->job_number() . " was not assigned") unless defined $job->starting_time();
			push @{$self->{reserved_jobs}}, $job;
		}

		$self->start_jobs();
	}

	# All jobs should be scheduled and started
	$logger->logdie('there are still jobs in the reserved queue: ' . join(' ', @{$self->{reserved_jobs}})) if (@{$self->{reserved_jobs}});

	$self->{execution_profile}->free_profiles();

	# Time measure
	$self->{run_time} = time() - $self->{run_time};

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
	my $logger = get_logger('Backfilling::start_jobs');
	my @newly_started_jobs;

	for my $job (@{$self->{reserved_jobs}}) {
		if (float_equal($job->starting_time(), $self->{current_time})) {
			##DEBUG_BEGIN
			$logger->debug("job " . $job->job_number() . " starting");
			##DEBUG_END

			$self->{events}->add(Event->new(JOB_COMPLETED_EVENT, $job->real_ending_time(), $job)) unless ($self->{uses_external_simulator});
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

=item reassign_jobs_two_positions()

Tries to reassign all the jobs that have been submitted but haven't started
yet.

For each job in the list, the routine checks if the job can start now. If that
is not possible, the job is returned to it's original position.

=cut

sub reassign_jobs_two_positions {
	my $self = shift;
	my $logger = get_logger('Backfilling::reassign_jobs_two_positions');

	for my $job (@{$self->{reserved_jobs}}) {

		if ($self->{execution_profile}->processors_available_at($self->{current_time}) >= $job->requested_cpus()) {
			my $job_starting_time = $job->starting_time();
			my $assigned_processors = $job->assigned_processors_ids();

			##DEBUG_BEGIN
			$logger->debug("enough processors for job " . $job->job_number());
			##DEBUG_END

			$self->{execution_profile}->remove_job($job, $self->{current_time});

			my $new_processors;
			if ($self->{execution_profile}->could_start_job_at($job, $self->{current_time})) {
				##DEBUG_BEGIN
				$logger->debug("could start job " . $job->job_number());
				##DEBUG_END

				$new_processors = $self->{execution_profile}->get_free_processors_for($job, $self->{current_time});
			}

			if (defined $new_processors) {
				##DEBUG_BEGIN
				$logger->debug("reassigning job " . $job->job_number() . " processors $new_processors");
				##DEBUG_END

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

	my $logger = get_logger('Backfilling::assign_job');
	##DEBUG_BEGIN
	$logger->debug("assigning job " . $job->job_number());
	##DEBUG_END

	my ($starting_time, $chosen_processors) = $self->{execution_profile}->find_first_profile_for($job);

	$job->assign_to($starting_time, $chosen_processors);
	$self->{execution_profile}->add_job_at($starting_time, $job);

	return;
}

1;
