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
		job_number => shift, #1
		submit_time => shift, #2
		wait_time => shift, #3
		run_time => shift, #4
		allocated_cpus => shift, #5
		avg_cpu_time => shift, #6
		used_mem => shift, #7
		requested_cpus => shift, #8
		requested_time => shift, #9
		requested_mem => shift, #10
		status => shift, #11, 0 = failed, 5 = cancelled, 1 = completed
		uid => shift, #12
		gid => shift, #13
		exec_number => shift, #14
		queue_number => shift, #15
		partition_number => shift, #16
		prec_job_number => shift, #17
		think_time_prec_job => shift, #18
	};

	bless $self, $class;
	return $self;
}

sub stringification {
	my $self = shift;

	return join(' ',
		$self->{job_number},
		$self->{submit_time},
		$self->{wait_time}, #update
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
	return $self->{wait_time}/$self->{run_time} + 1;
}

sub cmax {
	my ($self) = @_;
	return $self->{submit_time} + $self->{wait_time} + $self->{run_time};
}


sub submit_time {
	my ($self, $submit_time) = @_;
	$self->{submit_time} = $submit_time if defined $submit_time;
	return $self->{submit_time};
}

sub wait_time {
	my ($self, $wait_time) = @_;
	$self->{wait_time} = $wait_time if defined $wait_time;
	return $self->{wait_time};
}

sub job_number {
	my ($self, $job_number) = @_;
	$self->{job_number} = $job_number if defined $job_number;
	return $self->{job_number};
}

sub assign_to {
	my ($self, $starting_time, $assigned_processors) = @_;
	$self->{starting_time} = $starting_time;
	$self->{assigned_processors_ids} = $assigned_processors;
	$self->{wait_time} = $self->{starting_time} - $self->{submit_time};

	die "TODO: PROCESSORS";
	#$_->assign_job($self) for @{$self->{assigned_processors}};
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
