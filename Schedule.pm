package Schedule;
use parent 'Displayable';

use strict;
use warnings;

use List::Util qw(max sum);
use Time::HiRes qw(time);
use Log::Log4perl qw(get_logger);
use Data::Dumper;

use EventQueue;
use Platform;

#TODO Rewrite the local code in this package. This package only needs the
#cluster size for some minor things. I should be able to cleanup this package a
#lot by removing unecessary code, or code that is not generic to the idea of a
#Schedule.

# Creates a new Schedule object.
sub new {
	my $class = shift;
	my $platform = shift;
	my $trace = shift;

	my $self = {
		trace => $trace,
		platform => $platform,
		cmax => 0,
		uses_external_simulator => 0,
	};

	die 'not enough processors' if $self->{trace}->needed_cpus() > $self->{platform}->processors_number();
	$self->{trace}->unassign_jobs(); # make sure the trace is clean

	bless $self, $class;
	return $self;
}

sub new_simulation {
	my $class = shift;
	my $platform = shift;
	my $delay = shift;
	my $socket_file = shift;
	my $json_file = shift;

	my $self = {
		platform => $platform,
		job_delay => $delay,
		cmax => 0,
		uses_external_simulator => 1,
	};

	$self->{trace} = Trace->new();
	$self->{events} = EventQueue->new($socket_file, $json_file);

	bless $self, $class;
	return $self;
}

# Runs the basic schedule algorithm, calling the assign_job routine from the
# child class.
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

sub bounded_stretch {
	my $self = shift;

	my $jobs_number = scalar @{$self->{trace}->jobs()};
	my $total_bounded_stretch = sum map {$_->bounded_stretch(10)} (@{$self->{trace}->jobs()});

	return $total_bounded_stretch/$jobs_number;
}

sub stretch_sum_of_squares {
	my $self = shift;

	return sqrt(sum map {$_->bounded_stretch(10) ** 2} (@{$self->{trace}->jobs()}));
}

sub stretch_with_cpus_squared {
	my $self = shift;

	return sum map {$_->bounded_stretch_with_cpus_squared(10)} (@{$self->{trace}->jobs()});
}

sub stretch_with_cpus_log {
	my $self = shift;

	return sum map {$_->bounded_stretch_with_cpus_log(10)} (@{$self->{trace}->jobs()});
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

	# If there are no jobs we need to avoid the division
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
	my $h_ratio = 600/$self->{platform}->processors_number();

	my $current_x = $w_ratio * $time;
	print $filehandle "<line x1=\"$current_x\" x2=\"$current_x\" y1=\"0\" y2=\"600\" style=\"stroke:rgb(255,0,0);stroke-width:5\"/>\n";

	my $clusters_number = POSIX::ceil($self->{platform}->processors_number()
		/ $self->{platform}->cluster_size());
	my $cluster_size = 600/$self->{platform}->processors_number()
		* $self->{platform}->cluster_size();
	for my $cluster (1..$clusters_number) {
		my $cluster_y = $cluster * $cluster_size;
		print $filehandle "<line x1=\"0\" x2=\"800\" y1=\"$cluster_y\" y2=\"$cluster_y\" style=\"stroke:rgb(255,0,0);stroke-width:1\"/>\n";
	}

	$_->svg($filehandle, $w_ratio, $h_ratio, $time) for grep {defined $_->starting_time()} (@{$self->{trace}->jobs()});

	print $filehandle "</svg>\n";
	close $filehandle;
	return;
}

sub trace {
	my $self = shift;
	return $self->{trace};
}

sub platform_level_factor {
	my $self = shift;

	my $job_level_distances = sum map {$self->{platform}->relative_job_level_distance($_->list_of_used_clusters($self->{platform}->cluster_size()), $_->requested_cpus())} (@{$self->{trace}->jobs()});

	return $job_level_distances / scalar @{$self->{trace}->jobs()};
}

1;

