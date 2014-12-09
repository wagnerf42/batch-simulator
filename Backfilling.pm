package Backfilling;
use parent 'Schedule';
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use List::Util qw(max sum);

use Trace;
use Job;
use ExecutionProfile;
use Heap;
use Event;

use constant {
	SUBMISSION_EVENT => 0,
	JOB_COMPLETED_EVENT => 1
};

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	$self->{execution_profile} = new ExecutionProfile($self->{num_processors}, $self->{cluster_size}, $self->{version});

	return $self;
}

sub run {
	my $self = shift;

	die "not enough processors (we need " . $self->{trace}->needed_cpus() . ", we have " . $self->{num_processors} . ")" if $self->{trace}->needed_cpus() > $self->{num_processors};

	$self->{reserved_jobs} = []; #jobs not started yet
	$self->{started_jobs} = {}; #jobs which started before current time
	$self->{events} = Heap->new(Event->new(SUBMISSION_EVENT, -1));

	# Add all jobs to the queue
	$self->{events}->add(Event->new(SUBMISSION_EVENT, $_->submit_time(), $_)) for (@{$self->{jobs}});

	while (defined(my $event = $self->{events}->retrieve())) {

		my $job = $event->payload();
		$self->{current_time} = $event->timestamp();
		$self->{execution_profile}->set_current_time($self->{current_time});

		if ($event->type() == SUBMISSION_EVENT) {
			$self->assign_job($job);
		} else {
			# Finishing event
			delete $self->{started_jobs}->{$job->job_number()};

			#scrap execution profile
			$self->build_started_jobs_profile();

			#loop through all not yet started jobs and re-schedule them
			my $remaining_reserved_jobs = [];
			for my $job (@{$self->{reserved_jobs}}) {
				$self->assign_job($job);
				if ($job->starts_after($self->{current_time})) {
					push @$remaining_reserved_jobs, $job;
				}
			}
			$self->{reserved_jobs} = $remaining_reserved_jobs;
		}
	}
}

sub build_started_jobs_profile {
	my $self = shift;
	$self->{execution_profile} = new ExecutionProfile($self->{num_processors}, $self->{cluster_size}, $self->{version}, $self->{current_time});
	$self->{execution_profile}->add_job_at(0, $_) for values %{$self->{started_jobs}};
}

sub start_job {
	my $self = shift;
	my $job = shift;
	$self->{events}->add(Event->new(1, $job->ending_time(), $job));
	$self->{started_jobs}->{$job->job_number()} = $job;
}

sub assign_job {
	my ($self, $job) = @_;
	print STDERR "assigning job ".$job->job_number()." to exec-profile $self->{execution_profile}\n";
	#print "assigning job " . $job->job_number() . "\n";

	#get the first valid profile_id for our job
	my ($chosen_profile, $chosen_processors) = $self->{execution_profile}->find_first_profile_for($job);
	my $starting_time = $self->{execution_profile}->starting_time($chosen_profile);

	#assign job
	$job->assign_to($starting_time, $chosen_processors);

	#update profiles
	$self->{execution_profile}->add_job_at($chosen_profile, $job);
	$self->tycat();

	if ($job->starting_time() == $self->{current_time}) {
		$self->start_job($job);
	}
}

1;
