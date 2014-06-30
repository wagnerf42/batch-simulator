#!/usr/bin/perl

package Backfilling;
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
		num_processors => shift,
		processors => [],
		queued_jobs => [],
		profile => []
	};

	for my $id (0..($self->{num_processors} - 1)) {
		my $processor = new Processor($id);
		push $self->{processors}, $processor;
	}

	# The profile needs to start with one item stating that all processors are available on time 0
	my $profile_item = {
		available_cpus => $self->{num_processors},
		starting_time => 0
	};
	push $self->{profile}, $profile_item;

	bless $self, $class;
	return $self;
}

sub run {
	my $self = shift;

	map {$self->assign_job_profile($_)} @{$self->{trace}->jobs};
	@{$self->{queued_jobs}} = sort {$a->starting_time <=> $b->starting_time} @{$self->{queued_jobs}};
	map {$self->assign_job($_)} @{$self->{queued_jobs}};
}

sub assign_job {
	my $self = shift;
	my $job = shift;
	my $requested_cpus = $job->requested_cpus;

	my @sorted_processors = sort {$a->cmax <=> $b->cmax} @{$self->{processors}};
	my @selected_processors = splice(@sorted_processors, 0, $requested_cpus);

	my $starting_time = $selected_processors[$#selected_processors]->cmax;
	map {$_->assign_job($job, $starting_time)} @selected_processors;
}


sub assign_job_profile {
	my $self = shift;
	my $job = shift;

	my $profile = {
		start => -1,
		end => -1,
		new => 0
	};
	
	# This part is the basis for the conservative backfilling
	# The idea in the first step is just to check when there is enough space to
	# execute the job. The actual end of the execution time will be found in the
	# next step.
	for my $i (0..(@{$self->{profile}} - 1)) {
		if ($self->{profile}[$i]->{available_cpus} >= $job->requested_cpus) {
			$profile->{start} = $i;

			for my $j (($i + 1)..(@{$self->{profile}} - 1)) {
				if (($self->{profile}[$j]->{starting_time} < $self->{profile}[$i]->{starting_time} + $job->run_time) && ($self->{profile}[$j]->{available_cpus} < $job->requested_cpus)) {
					$profile->{start} = -1;
					last;
				}

				elsif ($self->{profile}[$j]->{starting_time} == $self->{profile}[$i]->{starting_time} + $job->run_time) {
					$profile->{end} = $j;
					last;
				}

				elsif ($self->{profile}[$j]->{starting_time} > $self->{profile}[$i]->{starting_time} + $job->run_time) {
					$profile->{end} = $j;
					$profile->{new} = 1;
					last;
				}
			}

			# Found a good starting time candidate
			if ($profile->{start} != -1) {
				last;
			}

		}
	}

	# I think it's ok and this will never happen but it's better to put it nonetheless
	if ($profile->{start} == -1) {
		die "This was not supposed to happen";
	}

	if ($profile->{end} == -1) {
		my $profile_item = {
			available_cpus => $self->{num_processors},
			starting_time => $self->{profile}[$profile->{start}]->{starting_time} + $job->run_time
		};

		push $self->{profile}, $profile_item;
		$profile->{end} = @{$self->{profile}} - 1;
	}

	elsif ($profile->{new} == 1) {
		my $profile_item = {
			available_cpus => $self->{profile}[$profile->{end} - 1]->{available_cpus},
			starting_time => $self->{profile}[$profile->{start}]->{starting_time} + $job->run_time
		};

		splice($self->{profile}, $profile->{end}, 0, $profile_item);
	}

	for my $i ($profile->{start}..($profile->{end} - 1)) {
		$self->{profile}[$i]->{available_cpus} -= $job->requested_cpus;
	}

	$job->starting_time($self->{profile}[$profile->{start}]->{starting_time});
	push $self->{queued_jobs}, $job;

	print "Assigned job $job->{job_number} on time $self->{profile}[$profile->{start}]->{starting_time}\n";
}

sub print_svg {
	my $self = shift;
	my $svg_filename = shift;
	my $pdf_filename = shift;

	open(my $filehandler, '>', $svg_filename);

	my @sorted_processors = sort {$a->cmax <=> $b->cmax} @{$self->{processors}};
	print $filehandler "<svg width=\"" . $sorted_processors[$#sorted_processors]->cmax * 5 . "\" height=\"" . @{$self->{processors}} * 20 . "\">\n";

	for my $processor (@{$self->{processors}}) {
		for my $job (@{$processor->jobs}) {
			$job->save_svg($filehandler, $processor->id);
		}
	}

	print $filehandler "</svg>\n";
	close $filehandler;

	# Convert the SVG file to PDF so that both are available
	`inkscape $svg_filename --export-pdf=$pdf_filename`
}

1;

