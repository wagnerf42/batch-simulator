package Backfilling;
use parent 'Schedule';
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use List::Util qw(max sum);
use Exporter qw(import);
use Carp;
use Time::HiRes qw(time);

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

our @EXPORT = qw(BASIC BEST_EFFORT_CONTIGUOUS CONTIGUOUS BEST_EFFORT_LOCAL LOCAL NEW_EXECUTION_PROFILE REUSE_EXECUTION_PROFILE);

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	$self->{execution_profile} = new ExecutionProfile($self->{num_processors}, $self->{cluster_size}, $self->{reduction_algorithm});

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

		# Flag to see if any job ends before declared time
		my $reassign_jobs = 0;

		$self->{current_time} = $events_timestamp;
		$self->{execution_profile}->set_current_time($events_timestamp);

		if ($events_type == SUBMISSION_EVENT) {
			for my $event (@events) {
				my $job = $event->payload();
				$self->assign_job($job);

				# We did not implement the policy part so it's possible that the job starts now
				if ($job->starting_time() == $self->{current_time}) {
					$self->start_job($job);
				} else {
					push @{$self->{reserved_jobs}}, $job;
				}
			}
		} else {
			for my $event (@events) {
				my $job = $event->payload();
				$reassign_jobs = 1 if ($job->requested_time() != $job->run_time());
				delete $self->{started_jobs}->{$job->job_number()};
				$self->{execution_profile}->remove_job($job, $self->{current_time}) if ($job->requested_time() != $job->run_time());
			}

			if ($reassign_jobs) {
				my @remaining_reserved_jobs;
				for my $job (@{$self->{reserved_jobs}}) {
					if ($self->{execution_profile}->starting_time(0) == $self->{current_time} and $self->{execution_profile}->could_start_job_at($job, 0)) {
						# Job can start now, assign it again
						$self->{execution_profile}->remove_job($job, $self->{current_time});
						my $processors = $self->{execution_profile}->get_free_processors_for($job, 0);
						$job->assign_to($self->{current_time}, $processors);
						$self->{execution_profile}->add_job_at(0, $job, $self->{current_time});
						$self->start_job($job);
					} else {
						push @remaining_reserved_jobs, $job;
					}
				}

				$self->{reserved_jobs} = [@remaining_reserved_jobs];
			}
		}
	}
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
