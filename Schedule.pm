package Schedule;
use strict;
use warnings;
use EventQueue;

use List::Util qw(max sum);
use Time::HiRes qw(time);
use parent 'Displayable';

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

	$self->{cluster_size} = $self->{num_processors} unless (defined $self->{cluster_size} and $self->{cluster_size} > 0 and $self->{cluster_size} <= $self->{num_processors});

	bless $self, $class;
	return $self;
}

sub new_simulation {
	my $class = shift;

	my $self = {
		cluster_size => shift,
		reduction_algorithm => shift,
		cmax => 0,
		uses_external_simulator => 1
	};

	$self->{trace} = Trace->new();
	$self->{events} = EventQueue->new(shift);
	$self->{processors_number} = $self->{events}->cpu_number();

	$self->{cluster_size} = $self->{num_processors} unless (defined $self->{cluster_size} and $self->{cluster_size} > 0 and $self->{cluster_size} <= $self->{num_processors});

	bless $self, $class;
	return $self;
}

sub uses_external_simulator {
	my $self = shift;
	return $self->{uses_external_simulator};
}

=item run()

Runs the basic schedule algorithm, calling the assign_job routine from the child class.

=cut

sub run {
	my ($self) = @_;

	die 'not enough processors' if $self->{trace}->needed_cpus() > $self->{processors_number};

	$self->assign_job($_) for @{$self->{trace}->jobs()};

	return;
}

sub run_time {
	my ($self) = @_;
	return $self->{run_time};
}

sub sum_flow_time {
	my ($self) = @_;
	return sum map {$_->flow_time()} @{$self->{trace}->jobs()};
}

sub max_flow_time {
	my ($self) = @_;
	return max map {$_->flow_time()} @{$self->{trace}->jobs()};
}

sub mean_flow_time {
	my ($self) = @_;
	return $self->sum_flow_time() / @{$self->{trace}->jobs()};
}

sub max_stretch {
	my ($self) = @_;
	return max map {$_->stretch()} @{$self->{trace}->jobs()};
}

sub mean_stretch {
	my ($self) = @_;
	return (sum map {$_->stretch()} @{$self->{trace}->jobs()}) / @{$self->{trace}->jobs()};
}

sub cmax_estimation {
	my ($self, $time) = @_;
	return max map {$_->ending_time_estimation($time)} (grep {defined $_->starting_time()} (@{$self->{trace}->jobs()}));
}

sub contiguous_jobs_number {
	my ($self) = @_;
	return scalar grep {$_->get_processor_range()->contiguous($self->{processors_number})} @{$self->{trace}->jobs()};
}

sub local_jobs_number {
	my ($self) = @_;
	return scalar grep {$_->get_processor_range()->local($self->{cluster_size})} @{$self->{trace}->jobs()};
}

sub locality_factor {
	my ($self) = @_;
	my $used_clusters = 0;
	my $optimum_clusters = 0;

	for my $job (@{$self->{trace}->jobs()}) {
		$used_clusters += $job->used_clusters($self->{cluster_size});
		$optimum_clusters += $job->clusters_required($self->{cluster_size});
	}
	return ($used_clusters / $optimum_clusters);
}

sub locality_factor_2 {
	my ($self) = @_;
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

	my $cmax = $self->cmax_estimation($time);
	$cmax = 1 unless defined $cmax;
	print $filehandle "<svg width=\"800\" height=\"600\">\n";
	my $w_ratio = 800/$cmax;
	my $h_ratio = 600/$self->{processors_number};

	my $current_x = $w_ratio * $time;
	print $filehandle "<line x1=\"$current_x\" x2=\"$current_x\" y1=\"0\" y2=\"600\" style=\"stroke:rgb(255,0,0);stroke-width:5\"/>\n";

	$_->svg($filehandle, $w_ratio, $h_ratio, $time) for grep {defined $_->starting_time()} (@{$self->{trace}->jobs()});

	print $filehandle "</svg>\n";
	close $filehandle;
	return;
}

1;

