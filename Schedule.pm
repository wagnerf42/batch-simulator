package Schedule;
use strict;
use warnings;

use List::Util qw(max sum);
use Time::HiRes qw(time);

sub new {
	my ($class, $trace, $processors_number, $cluster_size, $reduction_algorithm) = @_;

	my $self = {
		trace => $trace,
		num_processors => $processors_number,
		cluster_size => $cluster_size,
		reduction_algorithm => $reduction_algorithm,
		contiguous_jobs_number => 0,
		local_jobs_number => 0,
		cmax => 0
	};

	# Make sure the trace is clean
	#$self->{trace}->reset();

	#$self->{jobs} = $self->{trace}->jobs();

	bless $self, $class;
	return $self;
}

sub run {
	my ($self) = @_;
	my $start_time = time();

	die 'not enough processors' if $self->{trace}->needed_cpus() > $self->{num_processors};

	for my $job (@{$self->{trace}->jobs()}) {
		$self->assign_job($job);
		$job->schedule_time(time() - $start_time);
	}

	$self->{run_time} = time() - $start_time;
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

sub cmax {
	my ($self) = @_;
	return max map {$_->ending_time()} @{$self->{trace}->jobs()};
}

sub cmax_estimation {
	my ($self, $time) = @_;
	return max map {$_->ending_time_estimation($time)} @{$self->{trace}->jobs()};
}

sub contiguous_jobs_number {
	my ($self) = @_;
	return scalar grep {$_->get_processor_range()->contiguous($self->{num_processors})} @{$self->{trace}->jobs()};
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
	my ($self, $svg_filename, $time) = @_;

	open(my $filehandle, "> $svg_filename") or die "unable to open $svg_filename";

	my $cmax = $self->compute_cmax_estimation($time);
	print $filehandle "<svg width=\"800\" height=\"600\">\n";
	my $w_ratio = 800/$cmax;
	my $h_ratio = 600/$self->{num_processors};

	my $current_x = $w_ratio * $time;
	print $filehandle "<line x1=\"$current_x\" x2=\"$current_x\" y1=\"0\" y2=\"600\" style=\"stroke:rgb(255,0,0);stroke-width:5\"/>\n";

	$_->svg($filehandle, $w_ratio, $h_ratio, $time) for grep {defined $_->starting_time()} (@{$self->{trace}->jobs()});

	print $filehandle "</svg>\n";
	close $filehandle;
}

my $file_count = 0;
sub tycat {
	my ($self, $time) = @_;
	#print STDERR "tycat $file_count\n";
	$time = 0 unless defined $time;

	my $user = $ENV{"USER"};
	my $dir = "$user";
	mkdir $dir unless -f $dir;
	$self->save_svg("$dir/$file_count.svg", $time);
	`tycat $dir/$file_count.svg`;
	$file_count++;
}

1;

