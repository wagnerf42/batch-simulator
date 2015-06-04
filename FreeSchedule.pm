package FreeSchedule;
use parent 'Schedule';
use strict;
use warnings;
use ExecutionProfile;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	$self->{execution_profile} = ExecutionProfile->new($self->{processors_number});
	$self->{current_time} = 0;
	return $self;
}

sub assign_job {
	my $self = shift;
	my $job = shift;
	my $duration = $job->run_time();
	my $cpu_number = $job->requested_cpus();
	my $allocated_space = $self->{execution_profile}->add_task(0, $duration, $cpu_number);
	$job->assign_to($allocated_space->starting_time(), $allocated_space->processors());
	$self->tycat();
	return;
}

1;
