#!/usr/bin/perl

package FCFS;
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
		processors => []
	};

	for my $id (0..($self->{num_processors} - 1)) {
		my $processor = new Processor($id);
		push $self->{processors}, $processor;
	}

	bless $self, $class;
	return $self;
}

sub run {
	my $self = shift;

	for my $job (@{$self->{trace}->jobs}) {
		$self->assign_fcfs_job($job);
	}
}

sub assign_fcfs_job {
	my $self = shift;
	my $job = shift;
	my $requested_cpus = $job->requested_cpus;

	my @sorted_processors = sort {$a->cmax <=> $b->cmax} @{$self->{processors}};
	my @selected_processors = splice(@sorted_processors, 0, $requested_cpus);

	my $starting_time = $selected_processors[$#selected_processors]->cmax;
	map {$_->assign_job($job, $starting_time)} @selected_processors;
}

sub print {
	my $self = shift;

	print "Printing schedule\n";
	map {$_->print_jobs()} @{$self->{processors}};
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

