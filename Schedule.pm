#!/usr/bin/perl

package Schedule;
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Job;
use Processor;

sub new {
	my $class = shift;
	my $self = {
		trace => shift,
	};
	
	bless $self, $class;

	return $self;
}

sub fcfs {
    my $self = shift;
    
    for my $job (@{$self->{trace}}) {
        $self->assign_fcfs_job($job);
    }
}

sub assign_fcfs_job {
    my $self = shift;
    my $job = shift;
    my @sorted_processors = sort {$a->get_cmax() <=> $b->get_cmax()} @{$self->{processors}};
    my $needed_processors_number = $job->get_processors_number();
    my @selected_processors = splice(@sorted_processors, 0, $needed_processors_number);
    map {$_->assign_job($job)} @selected_processors;
}

1;

