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

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	$self->{execution_profile} = new ExecutionProfile($self->{num_processors}, $self->{cluster_size}, $self->{version});

	return $self;
}

sub run {
	my $self = shift;

	my $current_time = 0;
	my $reserved_jobs = [];
	my $started_jobs = {};
	my $events = Heap->new(Event->new(0, -1));

	die "not enough processors (we need " . $self->{trace}->needed_cpus() . ", we have " . $self->{num_processors} . ")" if $self->{trace}->needed_cpus() > $self->{num_processors};

	# Add all jobs to the queue
	$events->add(Event->new(0, $_->submit_time(), $_)) for (@{$self->{jobs}});

	while (defined(my $event = $events->retrieve())) {
		print STDERR "Current time: $current_time, event type " . $event->type() . " job " . $event->payload() . "\n";

		my $job = $event->payload();

		# Submission event
		if ($event->type() == 0) {
			$current_time = $job->submit_time();
			$self->assign_job($job);

			# Job can start now
			if ($job->starting_time() == $current_time) {
				$events->add(Event->new(1, $job->ending_time(), $job));

				# Insert job in $self->{started_jobs}
				$started_jobs->{$job->job_number()} = $job;

			} else {
				# Insert job in $self->{reserved_jobs}
				push @{$reserved_jobs}, $job;
			}

		# Finishing event
		} else {
			$current_time = $job->ending_time();
			delete $started_jobs->{$job->job_number()};

			$self->{execution_profile} = new ExecutionProfile($self->{num_processors}, $self->{cluster_size}, $self->{version}, $current_time);
			$self->{execution_profile}->add_job_at(0, $_) for values(%$started_jobs);

			$self->assign_job($_) for @$reserved_jobs;
			my ($new_started_jobs, $new_reserved_jobs) = verify_starting_jobs($reserved_jobs, $current_time);
			$events->insert(Event->new(1, $_->ending_time(), $_)) for @$new_started_jobs;
			$reserved_jobs = $new_reserved_jobs;
			$started_jobs->{$_->job_number()} = $_ for @$new_started_jobs;
		}
	}
}

sub verify_starting_jobs {
	my ($reserved_jobs, $current_time) = @_;

	my $new_reserved_jobs = [];
	my $new_started_jobs = [];

	for my $job (@$reserved_jobs) {
		if ($job->starting_time() == $current_time) {
			push @$new_started_jobs, $job;
		} else {
			push @$new_reserved_jobs, $job;
		}
	}

	return ($new_started_jobs, $new_reserved_jobs);
}

sub assign_job {
	my ($self, $job) = @_;
	#print STDERR "assigning job ".$job->job_number()." to exec-profile $self->{execution_profile}\n";
	#print "assigning job " . $job->job_number() . "\n";

	#get the first valid profile_id for our job
	$self->{execution_profile}->set_current_time($job->submit_time());
	my ($chosen_profile, $chosen_processors) = $self->{execution_profile}->find_first_profile_for($job);
	my $starting_time = $self->{execution_profile}->starting_time($chosen_profile);

	#assign job
	$job->assign_to($starting_time, $chosen_processors);

	# update cmax
	$self->update_cmax($job->cmax());

	#update profiles
	$self->{execution_profile}->add_job_at($chosen_profile, $job);
}

1;
