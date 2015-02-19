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
use Profile;
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

		$self->{current_time} = $events_timestamp;
		$self->{execution_profile}->set_current_time($events_timestamp);

		#print STDERR "Event $events_type: @events\n\tcurrent time: $events_timestamp\n";

		if ($events_type == SUBMISSION_EVENT) {
			for my $event (@events) {
				my $job = $event->payload();
				$self->assign_job($job);
				#print STDERR "\tep a assign: $self->{execution_profile}\n";
				push @{$self->{reserved_jobs}}, $job;

			}
		} else {
			for my $event (@events) {
				my $job = $event->payload();
				#print STDERR "\tfinishing job [$job]\n";
				#print STDERR "\tstart ep $self->{execution_profile}\n";
				delete $self->{started_jobs}->{$job->job_number()};
				$self->{execution_profile}->remove_job($job, $self->{current_time}) if ($job->requested_time() != $job->run_time());
				#print STDERR "\tep a remove $self->{execution_profile}\n";
			}

			$self->reassign_jobs();
			#$self->tycat();
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
			$self->start_job($job);
		} else {
			push @remaining_reserved_jobs, $job;
		}
	}

	$self->{reserved_jobs} = \@remaining_reserved_jobs;
	return;
}

sub reassign_jobs {
	my $self = shift;

	#print STDERR "\tavailable cpus " . $self->{execution_profile}->processors_available_at($self->{current_time}) . "\n";

	for my $job (@{$self->{reserved_jobs}}) {
		#print STDERR "\treassigning job [$job]\n";
		if ($self->{execution_profile}->processors_available_at($self->{current_time}) >= $job->requested_cpus()) {
			#print STDERR "\twill move job [$job] - $job->{starting_time}\n" if ($job->{job_number} == 28);
			#print STDERR "\tep b remove $self->{execution_profile}\n" if ($job->{job_number} == 4);
			$self->{execution_profile}->remove_job($job, $self->{current_time});
			#print STDERR "\tep a remove $self->{execution_profile}\n" if ($job->{job_number} == 4);
			$self->assign_job($job);
			#print STDERR "\tep a assign $self->{execution_profile}\n" if ($job->{job_number} == 4);
		}
	}
	return;
}

sub start_job {
	my ($self, $job) = @_;
	#print STDERR "\tstarting job [$job]\n";
	$self->{events}->add(Event->new(JOB_COMPLETED_EVENT, $job->real_ending_time(), $job));
	$self->{started_jobs}->{$job->job_number()} = $job;
	return;
}

sub assign_job {
	my ($self, $job) = @_;
	my ($starting_time, $chosen_processors) = $self->{execution_profile}->find_first_profile_for($job, $self->{current_time});

	#print STDERR "\tassign_job $starting_time - $chosen_processors\n";

	if (defined $starting_time) {
		$job->assign_to($starting_time, $chosen_processors);


		# Update profiles
		$self->{execution_profile}->add_job_at($starting_time, $job, $self->{current_time});
	}

	#print STDERR "\tnew starting time: $starting_time\n";
	return;
}

1;
