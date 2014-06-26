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
		num_processors => shift,
		processors => []
	};

	for my $id (0..($self->{num_processors}-1)) {
		my $processor = new Processor($id);
		push $self->{processors}, $processor;
	}

	bless $self, $class;
	return $self;
}

sub fcfs {
	my $self = shift;

	for my $job (@{$self->{trace}->{jobs}}) {
		$self->assign_fcfs_job($job);
	}
}

sub assign_fcfs_job {
	my $self = shift;
	my $job = shift;
	my @sorted_processors = sort {$a->get_cmax() <=> $b->get_cmax()} @{$self->{processors}};
	my $requested_cpus = $job->get_requested_cpus();
	my @selected_processors = splice(@sorted_processors, 0, $requested_cpus);
	my $starting_time = $selected_processors[$#selected_processors]->get_cmax();
	map {$_->assign_job($job, $starting_time)} @selected_processors;
}

sub print_schedule {
	my $self = shift;

	print "Printing schedule\n";
	map {$_->print_jobs()} @{$self->{processors}};
}

sub print_svg {
	my $self = shift;
	my $svg_filename = shift;
	my $pdf_filename = shift;

	open(my $filehandler, '>', $svg_filename);

	my @sorted_processors = sort {$a->get_cmax() <=> $b->get_cmax()} @{$self->{processors}};

	print $filehandler "<svg width=\"" . $sorted_processors[$#sorted_processors]->get_cmax() * 5 . "\" height=\"" . @{$self->{processors}} * 20 . "\">\n";

	for my $processor (@{$self->{processors}}) {
		for my $job (@{$processor->{jobs}}) {
			print $filehandler 
					"    <rect x=\"" . 
					$job->{starting_time} * 5 . 
					"\" y=\"" . 
					$processor->{id} * 20 . 
					"\" width=\"" . 
					$job->{run_time} * 5 . 
					"\" height=\"20\" style=\"fill:blue;stroke:pink;stroke-width:5;fill-opacity:0.2;stroke-opacity:0.8\" />\n";
			
			print $filehandler 
					"    <text x=\"" . 
					($job->{starting_time} * 5 + 4) . 
					"\" y=\"" . 
					($processor->{id} * 20 + 15) . 
					"\" fill=\"black\">" . 
					$job->{job_number} . 
					"</text>\n";
			
		}
	}

	print $filehandler "</svg>\n";
	close $filehandler;

	# Convert the SVG file to PDF so that both are available
	`inkscape $svg_filename --export-pdf=$pdf_filename`
}

1;

