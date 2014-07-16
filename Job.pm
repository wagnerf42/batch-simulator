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

sub requested_cpus {
	my $self = shift;
	return $self->{requested_cpus};
}

sub run_time {
	my $self = shift;
	return $self->{run_time};
}

sub starting_time {
	my $self = shift;
	return $self->{starting_time};
}

sub ending_time {
	my $self = shift;
	return $self->{starting_time} + $self->{run_time};
}

sub submit_time {
	my $self = shift;
	return $self->{submit_time};
}

sub wait_time {
	my $self = shift;
	return $self->{wait_time};
}

sub job_number {
	my $self = shift;
	return $self->{job_number};
}

sub assign_to {
	my $self = shift;

	$self->{starting_time} = shift;
	$self->{assigned_processors} = shift;

	$_->assign_job($self) for @{$self->{assigned_processors}};
}

sub assigned_processors {
	my $self = shift;
	return $self->{assigned_processors};
}

sub first_processor {
	my $self = shift;

	if (@_) {
		$self->{first_processor} = shift;
	}

	return $self->{first_processor};
}

sub svg {
	my $self = shift;
	my $fh = shift;
	my $w_ratio = shift;
	my $h_ratio = shift;

	for my $processor (@{$self->{assigned_processors}}) {
		my $processor_id = $processor->id();
		my $x = $self->{starting_time} * $w_ratio;
		my $y = $processor_id * $h_ratio;
		my $w = $self->{run_time} * $w_ratio;
		my $h = $h_ratio;
		my $sw = min($w_ratio, $h_ratio) / 10;
		my $color = $svg_colors[$self->{job_number} % @svg_colors];
		print $fh "\t<rect x=\"$x\" y=\"$y\" width=\"$w\" height=\"$h\" style=\"fill:$color;stroke:black;stroke-width:$sw\"/>\n";
		$x = ($self->{starting_time}+$self->{run_time}/2) * $w_ratio;
		$y = ($processor_id+0.5) * $h_ratio;
		my $fs = min($w_ratio, $h_ratio) * 40;
		print $fh "\t<text x=\"$x\" y=\"$y\" fill=\"white\" font-family=\"Verdana\" text-anchor=\"middle\" alignment-baseline=\"middle\" font-size=\"$fs\">$self->{job_number}</text>\n";
	}
}

sub save_svg {
	my $self = shift;
	my $fh = shift;
	my $processor_id = shift;

	my $default_time_ratio = 5;
	my $default_processor_ratio = 20;

	print $fh "\t<rect x=\"" . $self->{starting_time} * $default_time_ratio . "\" y=\"" . $processor_id * $default_processor_ratio . "\" width=\"" . $self->{run_time} * $default_time_ratio . "\" height=\"20\" style=\"fill:blue;stroke:black;stroke-width:1;fill-opacity:0.2;stroke-opacity:0.8\" />\n";
	print $fh "\t<text x=\"" . ($self->{starting_time} * $default_time_ratio + 4) . "\" y=\"" . ($processor_id * $default_processor_ratio + 15) . "\" fill=\"black\">" . $self->{job_number} . "</text>\n";
}

1;
