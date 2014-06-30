#!/usr/bin/perl

package FCFSC;
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

	map {$self->assign_fcfs_contiguous_job($_)} @{$self->{trace}->jobs};
}

sub verify_available_block {
	my $self = shift;
	my $first_processor_id = shift;
	my $requested_cpus = shift;

	my $block = {
		first_processor_id => $first_processor_id,
		starting_time => $self->{processors}[$first_processor_id]->cmax,
		size => $requested_cpus
	};

	for my $processor_id ($first_processor_id..($first_processor_id + $requested_cpus - 1)) {
		if ($self->{processors}[$processor_id]->cmax > $block->{starting_time}) {
			$block->{starting_time} = $self->{processors}[$processor_id]->cmax;
		}
	}

	return $block;
}

sub assign_fcfs_contiguous_job {
	my $self = shift;
	my $job = shift;
	my $requested_cpus = $job->requested_cpus;
	my @available_blocks;

	for my $processor_id (0..($self->{num_processors} - $requested_cpus)) {
		my $block = $self->verify_available_block($processor_id, $requested_cpus);
		push @available_blocks, $block if defined $block;
	}

	my @sorted_blocks = sort {$a->{starting_time} <=> $b->{starting_time}} @available_blocks;
	my @selected_processors = @{$self->{processors}}[$sorted_blocks[0]->{first_processor_id}..($sorted_blocks[0]->{first_processor_id} + $sorted_blocks[0]->{size} - 1)];
	map {$_->assign_job($job, $sorted_blocks[0]->{starting_time})} @selected_processors;
	$job->{first_processor} = $sorted_blocks[0]->{first_processor_id};
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

