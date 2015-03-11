package Backfilling;
use parent 'Schedule';
use strict;
use warnings;

use Carp;
use Exporter qw(import);

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

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	$self->{execution_profile} = ExecutionProfile->new($self->{num_processors}, $self->{cluster_size}, $self->{reduction_algorithm});
	return $self;
}

sub run {
	my $self = shift;

	# Jobs not started yet
	$self->{reserved_jobs} = [];

	# Jobs which started before current time
	$self->{started_jobs} = {};
	$self->{events} = Heap->new(Event->new(SUBMISSION_EVENT, -1));

	# Add all jobs to the queue
	$self->{events}->add(Event->new(SUBMISSION_EVENT, $_->submit_time(), $_)) for (@{$self->{trace}->jobs()});

	while ($self->{events}->not_empty()) {
		# Events coming from the Heap will have same timestamp and type
		my @events = $self->{events}->retrieve_all();
		my $events_type = $events[0]->type();
		my $events_timestamp = $events[0]->timestamp();

		$self->{current_time} = $events_timestamp;
		$self->{execution_profile}->set_current_time($events_timestamp);

		if ($events_type == SUBMISSION_EVENT) {
			for my $event (@events) {
				my $job = $event->payload();
				$self->assign_job($job);
				die "job $job is not assigned" unless defined $job->starting_time();
				push @{$self->{reserved_jobs}}, $job;
			}
		} else {
			for my $event (@events) {
				my $job = $event->payload();
				delete $self->{started_jobs}->{$job->job_number()};
				$self->{execution_profile}->remove_job($job, $self->{current_time}) if ($job->requested_time() != $job->run_time());
			}

			$self->reassign_jobs();
			#$self->reassign_jobs_two_positions();
		}

		$self->start_jobs();
	}
	return;
}

sub start_jobs {
	my $self = shift;
	my @remaining_reserved_jobs;

	for my $job (@{$self->{reserved_jobs}}) {
		if ($job->starting_time() == $self->{current_time}) {
			$self->{events}->add(Event->new(JOB_COMPLETED_EVENT, $job->real_ending_time(), $job));
			$self->{started_jobs}->{$job->job_number()} = $job;
		} else {
			push @remaining_reserved_jobs, $job;
		}
	}

	$self->{reserved_jobs} = \@remaining_reserved_jobs;
	return;
}

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

sub reassign_jobs {
	my $self = shift;

	for my $job (@{$self->{reserved_jobs}}) {
		if ($self->{execution_profile}->processors_available_at($self->{current_time}) >= $job->requested_cpus()) {
			$self->{execution_profile}->remove_job($job, $self->{current_time});
			$self->assign_job($job);
		}
	}
	return;
}

sub assign_job {
	my $self = shift;
	my $job = shift;

	my ($starting_time, $chosen_processors) = $self->{execution_profile}->find_first_profile_for($job, $self->{current_time});
	$job->assign_to($starting_time, $chosen_processors);
	$self->{execution_profile}->add_job_at($starting_time, $job, $self->{current_time});

	return;
}

1;
