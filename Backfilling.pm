package Backfilling;
use parent 'Schedule';
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Job;
use ExecutionProfile;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	$self->{execution_profile} = new ExecutionProfile($self->{num_processors}, $self->{cluster_size}, $self->{version});

	return $self;
}

sub assign_job {
	my ($self, $job) = @_;
	#print STDERR "assigning job ".$job->job_number()." to exec-profile $self->{execution_profile}\n";
	#print "assigning job " . $job->job_number() . "\n";
	my $requested_cpus = $job->requested_cpus();

	#get the first valid profile_id for our job
	$self->{execution_profile}->set_current_time($job->submit_time());
	my ($chosen_profile, $chosen_processors) = $self->{execution_profile}->find_first_profile_for($job);
	my $starting_time = $self->{execution_profile}->starting_time($chosen_profile);

	#assign job
	$job->assign_to($starting_time, $chosen_processors);

	# update cmax
	$self->update_cmax($job->cmax());

	# temporary to a experiment
	$job->{schedule_cmax} = $self->{cmax};

	#update profiles
	$self->{execution_profile}->add_job_at($chosen_profile, $job);
}

1;
