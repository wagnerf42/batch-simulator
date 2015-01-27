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
	SUBMISSION_EVENT => 0,
	JOB_COMPLETED_EVENT => 1
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

	$self->{remaining_jobs} = @{$self->{trace}->jobs()};

	while (defined(my $event = $self->{events}->retrieve())) {
		my $job = $event->payload();
		$self->{current_time} = $event->timestamp();
		$self->{execution_profile}->set_current_time($self->{current_time});

		if ($event->type() == SUBMISSION_EVENT) {
			$self->assign_job($job, $self->{reserved_jobs});
		} else {
			delete $self->{started_jobs}->{$job->job_number()};

			if ($job->requested_time() != $job->run_time()) {
				if ($self->{schedule_algorithm} == NEW_EXECUTION_PROFILE) {
					$self->build_started_jobs_profile();
				} else {
					# Remove the job from the execution profile to reuse the remaining time.
					$self->{execution_profile}->remove_job($job, $self->{current_time});
				}

				# Loop through all not yet started jobs and re-schedule them
				my $remaining_reserved_jobs = [];
				for my $rescheduled_job (@{$self->{reserved_jobs}}) {
					$self->{execution_profile}->remove_job($rescheduled_job, $self->{current_time}) if $self->{schedule_algorithm} == REUSE_EXECUTION_PROFILE;
					$rescheduled_job->unassign();
					$self->assign_job($rescheduled_job, $remaining_reserved_jobs);
				}
				$self->{reserved_jobs} = $remaining_reserved_jobs;

				$self->{remaining_jobs}--;
			} else {
				#only check which job starts now
				#TODO: factorize code ?
				my @still_reserved_jobs;
				for my $job (@{$self->{reserved_jobs}}) {
					if (defined $job->starting_time() and $job->starting_time() == $self->{current_time}) {
						$self->start_job($job);
					} else {
						push @still_reserved_jobs, $job;
					}
				}
				$self->{reserved_jobs} = [@still_reserved_jobs];
			}
		}
	}
}

sub build_started_jobs_profile {
	my $self = shift;
	$self->{execution_profile} = new ExecutionProfile($self->{num_processors}, $self->{cluster_size}, $self->{reduction_algorithm}, $self->{current_time});
	$self->{execution_profile}->add_job_at(0, $_, $self->{current_time}) for values %{$self->{started_jobs}};
}

sub start_job {
	my ($self, $job) = @_;
	$self->{events}->add(Event->new(1, $job->real_ending_time(), $job));
	$self->{started_jobs}->{$job->job_number()} = $job;
}

sub assign_job {
	my ($self, $job, $still_reserved_jobs) = @_;
	my ($chosen_profile, $chosen_processors) = $self->{execution_profile}->find_first_profile_for($job);

	my $job_starts = 0;
	if (defined $chosen_profile) {
		my $starting_time = $self->{execution_profile}->starting_time($chosen_profile);

		$job->assign_to($starting_time, $chosen_processors);

		# Update profiles
		$self->{execution_profile}->add_job_at($chosen_profile, $job, $self->{current_time});

		if ($job->starting_time() == $self->{current_time}) {
			$self->start_job($job);
			$job_starts = 1;
		}
	}

	push @{$still_reserved_jobs}, $job unless $job_starts;
}

1;
