package Job;
use strict;
use warnings;
use List::Util qw(min);
use Data::Dumper qw(Dumper);

use overload
    '""' => \&stringification;

my @svg_colors = qw(red green blue purple orange saddlebrown mediumseagreen darkolivegreen darkred dimgray mediumpurple midnightblue olive);

sub new {
	my $class = shift;

	my $self = {
		job_number => shift,
		submit_time => shift,
		wait_time => shift,
		run_time => shift,
		allocated_cpus => shift,
		avg_cpu_time => shift,
		used_mem => shift,
		requested_cpus => shift,
		requested_time => shift,
		requested_mem => shift,
		status => shift,
		uid => shift,
		gid => shift,
		exec_number => shift,
		queue_number => shift,
		partition_number => shift,
		prec_job_number => shift,
		think_time_prec_job => shift,
	};

	bless $self, $class;
	return $self;
}

sub stringification {
	my $self = shift;

	return join(' ',
		$self->{job_number},
		$self->{submit_time},
		$self->{wait_time},
		$self->{run_time},
		$self->{allocated_cpus},
		$self->{avg_cpu_time},
		$self->{used_mem},
		$self->{requested_cpus},
		$self->{requested_time},
		$self->{requested_mem},
		$self->{status},
		$self->{uid},
		$self->{gid},
		$self->{exec_number},
		$self->{queue_number},
		$self->{partition_number},
		$self->{prec_job_number},
		$self->{think_time_prec_job}
	);
}

sub copy {
	my $class = shift;
	my $original = shift;
	my $self = {};
	$self->{$_} = $original->{$_} for (keys %{$original});
	$self->{assigned_processors} = [];
	bless $self, $class;
}

sub requested_cpus {
	my ($self) = @_;
	return $self->{allocated_cpus};
}

sub run_time {
	my ($self, $run_time) = @_;
	$self->{run_time} = $run_time if defined $run_time;
	return $self->{run_time};
}

sub requested_time {
	my ($self, $requested_time) = @_;
	$self->{requested_time} = $requested_time if defined $requested_time;
	return $self->{requested_time};
}

sub starting_time {
	my ($self, $starting_time) = @_;
	$self->{starting_time} = $starting_time if defined $starting_time;
	return $self->{starting_time};
}

sub ending_time {
	my ($self) = @_;
	return $self->{starting_time} + $self->{run_time};
}

sub flow_time {
	my ($self) = @_;
	return $self->{starting_time} + $self->{run_time} - $self->{submit_time};
}

sub stretch {
	my ($self) = @_;
	return ($self->{starting_time} + $self->{run_time} - $self->{submit_time})/$self->{run_time};
}

sub submit_time {
	my ($self, $submit_time) = @_;
	$self->{submit_time} = $submit_time if defined $submit_time;
	return $self->{submit_time};
}

sub wait_time {
	my ($self) = @_;
	return $self->{wait_time};
}

sub job_number {
	my ($self, $job_number) = @_;
	$self->{job_number} = $job_number if defined $job_number;
	return $self->{job_number};
}

sub assign_to {
	my ($self, $starting_time, $assigned_processors) = @_;
	$self->{starting_time} = $starting_time if defined $starting_time;
	$self->{assigned_processors} = $assigned_processors if defined $assigned_processors;

	$_->assign_job($self) for @{$self->{assigned_processors}};
}

sub assigned_processors {
	my ($self) = @_;
	return $self->{assigned_processors};
}

sub first_processor {
	my ($self, $first_processor) = @_;
	$self->{first_processor} = $first_processor if defined $first_processor;
	return $self->{first_processor};
}

sub svg {
	my ($self, $fh, $w_ratio, $h_ratio) = @_;

	for my $processor (@{$self->{assigned_processors}}) {
		my $processor_id = $processor->id();
		my $x = $self->{starting_time} * $w_ratio;
		my $y = $processor_id * $h_ratio;
		my $w = $self->{run_time} * $w_ratio;
		my $h = $h_ratio;
		my $sw = min($w_ratio, $h_ratio) / 10;
		my $color = $svg_colors[$self->{job_number} % @svg_colors];
		print $fh "\t<rect x=\"$x\" y=\"$y\" width=\"$w\" height=\"$h\" style=\"fill:$color;fill-opacity:0.2;stroke:black;stroke-width:$sw\"/>\n";
		$x = ($self->{starting_time}+$self->{run_time}/2) * $w_ratio;
		$y = ($processor_id+0.5) * $h_ratio;
		my $fs = min($h_ratio, $w/5);
		my $text_y = $y + $fs*0.35;
		print $fh "\t<text x=\"$x\" y=\"$text_y\" fill=\"white\" font-family=\"Verdana\" text-anchor=\"middle\" font-size=\"$fs\">$self->{job_number}</text>\n";
	}
}

sub reset {
	my ($self) = @_;
	delete $self->{starting_time};
	delete $self->{first_processor};
	delete $self->{assigned_processors};
}

sub save_svg {
	my ($self, $fh, $processor_id) = @_;
	my $default_time_ratio = 5;
	my $default_processor_ratio = 20;

	print $fh "\t<rect x=\"" . $self->{starting_time} * $default_time_ratio . "\" y=\"" . $processor_id * $default_processor_ratio . "\" width=\"" . $self->{run_time} * $default_time_ratio . "\" height=\"20\" style=\"fill:blue;stroke:black;stroke-width:1;fill-opacity:0.2;stroke-opacity:0.8\" />\n";
	print $fh "\t<text x=\"" . ($self->{starting_time} * $default_time_ratio + 4) . "\" y=\"" . ($processor_id * $default_processor_ratio + 15) . "\" fill=\"black\">" . $self->{job_number} . "</text>\n";
}

1;
