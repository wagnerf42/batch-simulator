package Schedule;
use parent 'Displayable';

use strict;
use warnings;

use List::Util qw(max sum);
use Time::HiRes qw(time);
use Log::Log4perl qw(get_logger);

use EventQueue;

=head1 NAME

Schedule - Basic class for schedule algorithms

This class doesn't have all the logic for the schedule algorithm (i.e. it doesn't
implement the assign_job routine). Instead, another class must inherit from it and
complete the implementation (i.e. backfilling algorithm).

=over 12

=item new(trace, processors_number, cluster_size, reduction_algorithm)

Creates a new Schedule object.

=cut

sub new {
	my $class = shift;

	my $self = {
		trace => shift,
		processors_number => shift,
		cluster_size => shift,
		reduction_algorithm => shift,
		cmax => 0,
		uses_external_simulator => 0
	};

	die 'not enough processors' if $self->{trace}->needed_cpus() > $self->{processors_number};
	$self->{trace}->unassign_jobs(); # make sure the trace is clean

	$self->{cluster_size} = $self->{processors_number} unless (defined $self->{cluster_size} and $self->{cluster_size} > 0 and $self->{cluster_size} <= $self->{processors_number});

	bless $self, $class;
	return $self;
}

sub new_simulation {
	my $class = shift;
	my $cluster_size = shift;
	my $reduction_algorithm = shift;
	my $delay = shift;
	my $socket_file = shift;
	my $json_file = shift;

	my $self = {
		cluster_size => $cluster_size,
		reduction_algorithm => $reduction_algorithm,
		cmax => 0,
		uses_external_simulator => 1,
		job_delay => $delay,
	};

	$self->{trace} = Trace->new();
	$self->{events} = EventQueue->new($socket_file, $json_file);
	$self->{processors_number} = $self->{events}->cpu_number();

	$self->{cluster_size} = $self->{processors_number} unless (defined $self->{cluster_size} and $self->{cluster_size} > 0 and $self->{cluster_size} <= $self->{processors_number});

	bless $self, $class;
	return $self;
}

=item run()

Runs the basic schedule algorithm, calling the assign_job routine from the child class.

=cut

sub run {
	my $self = shift;

	$self->assign_job($_) for @{$self->{trace}->jobs()};

	return;
}

sub run_time {
	my $self = shift;
	return $self->{run_time};
}

sub sum_flow_time {
	my $self = shift;
	return sum map {$_->flow_time()} @{$self->{trace}->jobs()};
}

sub max_flow_time {
	my $self = shift;
	return max map {$_->flow_time()} @{$self->{trace}->jobs()};
}

sub mean_flow_time {
	my $self = shift;
	return $self->sum_flow_time() / @{$self->{trace}->jobs()};
}

sub max_stretch {
	my $self = shift;
	return max map {$_->stretch()} @{$self->{trace}->jobs()};
}

sub mean_stretch {
	my $self = shift;
	return (sum map {$_->stretch()} @{$self->{trace}->jobs()}) / @{$self->{trace}->jobs()};
}

#TODO Check this (delay)
sub cmax {
	my $self = shift;
	return max map {$_->real_ending_time()} (@{$self->{trace}->jobs()});
}

sub contiguous_jobs_number {
	my $self = shift;
	return scalar grep {$_->assigned_processors_ids()->contiguous($self->{processors_number})} (@{$self->{trace}->jobs()});
}

sub local_jobs_number {
	my $self = shift;
	return scalar grep {$_->assigned_processors_ids()->local($self->{cluster_size})} (@{$self->{trace}->jobs()});
}

sub locality_factor {
	my $self = shift;
	my $used_clusters = 0;
	my $optimum_clusters = 0;

	for my $job (@{$self->{trace}->jobs()}) {
		$used_clusters += $job->used_clusters($self->{cluster_size});
		$optimum_clusters += $job->clusters_required($self->{cluster_size});
	}

  return 1 unless ($optimum_clusters != 0);
	return ($used_clusters / $optimum_clusters);
}

sub locality_factor_2 {
	my $self = shift;
	my $sum_of_ratios = 0;

	for my $job (@{$self->{trace}->jobs()}) {
		my $used_clusters = $job->used_clusters($self->{cluster_size});
		my $optimum_clusters = $job->clusters_required($self->{cluster_size});
		$sum_of_ratios += $used_clusters / $optimum_clusters;
	}

	return $sum_of_ratios;
}

sub save_svg {
	my ($self, $svg_filename) = @_;
	my $time = $self->{current_time};
	$time = 0 unless defined $time;

	open(my $filehandle, '>', "$svg_filename") or die "unable to open $svg_filename";

	my $cmax = $self->cmax();
	$cmax = 1 unless defined $cmax;
	print $filehandle "<svg width=\"800\" height=\"600\">\n";
	my $w_ratio = 800/$cmax;
	my $h_ratio = 600/$self->{processors_number};

	my $current_x = $w_ratio * $time;
	print $filehandle "<line x1=\"$current_x\" x2=\"$current_x\" y1=\"0\" y2=\"600\" style=\"stroke:rgb(255,0,0);stroke-width:5\"/>\n";

	my $clusters_number = POSIX::ceil($self->{processors_number}/$self->{cluster_size});
	my $cluster_size = 600/$self->{processors_number}*$self->{cluster_size};
	for my $cluster (1..$clusters_number) {
		my $cluster_y = $cluster * $cluster_size;
		print $filehandle "<line x1=\"0\" x2=\"800\" y1=\"$cluster_y\" y2=\"$cluster_y\" style=\"stroke:rgb(255,0,0);stroke-width:3\"/>\n";

	}

	$_->svg($filehandle, $w_ratio, $h_ratio, $time) for grep {defined $_->starting_time()} (@{$self->{trace}->jobs()});

	print $filehandle "</svg>\n";
	close $filehandle;
	return;
}

1;

