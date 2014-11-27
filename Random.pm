package Random;
use parent 'Schedule';

use strict;
use warnings;

use List::Util qw(max);
use ProcessorsSet;
use Data::Dumper qw(Dumper);

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	my $p = new Algorithm::Permute($self->{trace}->jobs());
	my @res = $p->next();
	$self->{trace}->jobs(\@res);

	return $self;
}


sub assign_job {
	my ($self, $job) = @_;
	my $requested_cpus = $job->requested_cpus;

	@{$self->{processors}} = sort {$a->cmax() <=> $b->cmax()} @{$self->{processors}};
	my @selected_processors = @{$self->{processors}}[0..($requested_cpus - 1)];
	my $starting_time = max ($job->submit_time(), $selected_processors[$#selected_processors]->cmax());

	my @candidate_processors;
	for my $processor (@{$self->{processors}}) {
		push @candidate_processors, $processor if $processor->cmax() <= $starting_time;
	}

	my $set = new ProcessorsSet(\@candidate_processors, scalar @{$self->{processors}});

	if ($self->{version} == 0) {
		$set->reduce_to_first($requested_cpus);
	}

	elsif ($self->{version} == 1) {
		$set->reduce_to_contiguous_best_effort($requested_cpus);
	}

	$job->assign_to($starting_time, [$set->processors()]);
}

1;
