package Schedule;
use strict;
use warnings;

use List::Util qw(max sum);
use Time::HiRes qw(time);

local $| = 1;

sub new {
	my ($class, $trace, $processors_number, $cluster_size, $version) = @_;

	my $self = {
		trace => $trace,
		num_processors => $processors_number,
		cluster_size => $cluster_size,
		version => $version,
		contiguous_jobs_number => 0,
		local_jobs_number => 0,
		cmax => 0
	};

	# If no cluster size was chosen, use the number of processors as cluster size
	$self->{cluster_size} = $self->{num_processors} unless defined $self->{cluster_size};

	# If no algorithm version was chosen, use 0 as the default version
	$self->{version} = 0 unless defined $self->{version};

	# Make sure the trace is clean
	#$self->{trace}->reset();

	#shortcut for access to jobs list (which is also in trace)
	$self->{jobs} = $self->{trace}->jobs();

	bless $self, $class;
	return $self;
}

sub run {
	my $self = shift;
	my $start_time = time();

	die "not enough processors (we need " . $self->{trace}->needed_cpus() . ", we have " . $self->{num_processors} . ")" if $self->{trace}->needed_cpus() > $self->{num_processors};

	for my $job (@{$self->{jobs}}) {
		$self->assign_job($job);
		$job->schedule_time(time() - $start_time);
	}

	$self->{run_time} = time() - $start_time;
}

sub run_time {
	my $self = shift;
	return $self->{run_time};
}

sub sum_flow_time {
	my $self = shift;
	return sum map {$_->flow_time()} @{$self->{jobs}};
}

sub max_flow_time {
	my $self = shift;
	return max map {$_->flow_time()} @{$self->{jobs}};
}

sub mean_flow_time {
	my $self = shift;
	return $self->sum_flow_time() / @{$self->{jobs}};
}

sub max_stretch {
	my $self = shift;
	return max map {$_->stretch()} @{$self->{jobs}};
}

sub mean_stretch {
	my ($self) = @_;
	return (sum map {$_->stretch()} @{$self->{jobs}}) / @{$self->{jobs}};
}

sub compute_cmax {
	my $self = shift;
	return max map {$_->ending_time()} @{$self->{jobs}};
}

sub contiguous_jobs_number {
	my $self = shift;
	return scalar grep {$_->get_processor_range()->contiguous($self->{num_processors})} @{$self->{jobs}};
}

sub local_jobs_number {
	my $self = shift;
	return scalar grep {$_->get_processor_range()->local($self->{cluster_size})} @{$self->{jobs}};
}

sub locality_factor {
	my $self = shift;
	my $used_clusters = 0;
	my $optimum_clusters = 0;
	for my $job (@{$self->{jobs}}) {
		$used_clusters += $job->used_clusters($self->{cluster_size});
		$optimum_clusters += $job->clusters_required($self->{cluster_size});
	}
	return ($used_clusters / $optimum_clusters);
}

sub locality_factor_2 {
	my $self = shift;
	my $sum_of_ratios = 0;
	for my $job (@{$self->{jobs}}) {
		my $used_clusters = $job->used_clusters($self->{cluster_size});
		my $optimum_clusters = $job->clusters_required($self->{cluster_size});
		$sum_of_ratios += $used_clusters / $optimum_clusters;
	}
	return $sum_of_ratios;
}

sub save_svg {
	my ($self, $svg_filename) = @_;

	open(my $filehandle, "> $svg_filename") or die "unable to open $svg_filename";

	my $cmax = $self->compute_cmax();
	print $filehandle "<svg width=\"800\" height=\"600\">\n";
	my $w_ratio = 800/$cmax;
	my $h_ratio = 600/$self->{num_processors};

	$_->svg($filehandle, $w_ratio, $h_ratio) for grep {defined $_->starting_time()} (@{$self->{jobs}});

	print $filehandle "</svg>\n";
	close $filehandle;
}

my $file_count = 0;
sub tycat {
	my ($self) = @_;

	my $user = $ENV{"USER"};
	my $dir = "/tmp/$user";
	mkdir $dir unless -f $dir;
	$self->save_svg("$dir/$file_count.svg");
	`tycat $dir/$file_count.svg`;
	$file_count++;
}

1;

