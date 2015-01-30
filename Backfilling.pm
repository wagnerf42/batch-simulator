package Backfilling;
use parent 'Schedule';
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use List::Util qw(max sum);
use Exporter qw(import);
use Carp;

use Trace;
use Job;
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

use constant {
	NEW_EXECUTION_PROFILE => 0,
	REUSE_EXECUTION_PROFILE => 1
};

our @EXPORT = qw(BASIC BEST_EFFORT_CONTIGUOUS CONTIGUOUS BEST_EFFORT_LOCAL LOCAL NEW_EXECUTION_PROFILE REUSE_EXECUTION_PROFILE);

sub new {
	my $class = shift;
	my $schedule_algorithm = shift;

	my $self = $class->SUPER::new(@_);

	$self->{execution_profile} = new ExecutionProfile($self->{num_processors}, $self->{cluster_size}, $self->{reduction_algorithm});
	$self->{schedule_algorithm} = $schedule_algorithm;

	return $self;
}

sub run {
	my $self = shift;

	die 'not enough processors' if $self->{trace}->needed_cpus() > $self->{num_processors};

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

		# Flag to see if any job ends before declared time
		my $reassign_jobs = 0;

		$self->{current_time} = $events_timestamp;
		$self->{execution_profile}->set_current_time($events_timestamp);

		if ($events_type == SUBMISSION_EVENT) {
			for my $event (@events) {
				my $job = $event->payload();
				push @{$self->{reserved_jobs}}, $job;
				$self->assign_job($job);
			}
		} else {
			delete $self->{started_jobs}->{$_->payload()} for (@events);

			my $reassign_jobs = $self->compute_if_jobs_need_reassignment(\@events);
			if ($reassign_jobs) {
				if ($self->{schedule_algorithm} == NEW_EXECUTION_PROFILE) {
					$self->update_profiles_new();
				} else {
					$self->update_profiles_reuse(\@events);
				}
				$self->reschedule_jobs();
			}
		}
		$self->start_jobs();
	}
}

sub compute_if_jobs_need_reassignment {
	my $self = shift;
	my $events = shift;
	for my $event (@$events) {
		my $job = $event->payload();
		if ($job->requested_time() != $job->run_time()) {
			return 1;
		}
	}
	return 0;
}

sub start_jobs {
	my $self = shift;
	my @remaining_reserved_jobs;
	for my $job (@{$self->{reserved_jobs}}) {
		if (defined $job->starting_time() and $job->starting_time() == $self->{current_time}) {
			$self->start_job($job);
		} else {
			push @remaining_reserved_jobs, $job;
		}
	}
	$self->{reserved_jobs} = [@remaining_reserved_jobs];
	return;
}

sub update_profiles_new {
	my $self = shift;
	$self->{execution_profile} = new ExecutionProfile($self->{num_processors}, $self->{cluster_size}, $self->{reduction_algorithm}, $self->{current_time});
	$self->{execution_profile}->add_job_at(0, $_, $self->{current_time}) for values %{$self->{started_jobs}};
}

sub update_profiles_reuse {
	my $self = shift;
	my $events = shift;
	for my $event (@$events) {
		my $job = $event->payload();
		if ($job->requested_time() != $job->run_time()) {
			$self->{execution_profile}->remove_job($job, $self->{current_time});
		}
	}

	$self->{execution_profile}->remove_job($_, $self->{current_time}) for (@{$self->{reserved_jobs}});

	return;
}

sub reschedule_jobs {
	my $self = shift;
	# Remove, reassign and start jobs as necessary
	for my $job (@{$self->{reserved_jobs}}) {
		$job->unassign();
		$self->assign_job($job);
	}
	return ;
}

sub start_job {
	my ($self, $job) = @_;
	$self->{events}->add(Event->new(JOB_COMPLETED_EVENT, $job->real_ending_time(), $job));
	$self->{started_jobs}->{$job->job_number()} = $job;
}

sub assign_job {
	my ($self, $job) = @_;
	my ($chosen_profile, $chosen_processors) = $self->{execution_profile}->find_first_profile_for($job, $self->{current_time});

	if (defined $chosen_profile) {
		my $starting_time = $self->{execution_profile}->starting_time($chosen_profile);

		$job->assign_to($starting_time, $chosen_processors);

		# Update profiles
		$self->{execution_profile}->add_job_at($chosen_profile, $job, $self->{current_time});
	}
	return;
}

1;
