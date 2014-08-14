package Schedule;
use strict;
use warnings;

use Processor;
use List::Util qw(max sum);

sub new {
	my ($class, $trace, $processors_number, $cluster_size, $version) = @_;

	my $self = {
		trace => $trace,
		num_processors => $processors_number,
		cluster_size => $cluster_size,
		version => $version,
		processors => []
	};

	# If no cluster size was chosen, use the number of processors as cluster size
	$self->{cluster_size} = $self->{num_processors} unless defined $self->{cluster_size};

	# If no algorithm version was chosen, use 0 as the default version
	$self->{version} = 0 unless defined $self->{version};

	for my $id (0..($self->{num_processors} - 1)) {
		my $processor = new Processor($id, int($id/$self->{cluster_size}));
		push $self->{processors}, $processor;
	}

	# Make sure the trace is clean
	$self->{trace}->reset();

	bless $self, $class;
	return $self;
}

sub run {
	my ($self) = @_;
	my $start = time();

	die "not enough processors (we need " . $self->{trace}->needed_cpus() . ", we have " . $self->{num_processors} . ")" if $self->{trace}->needed_cpus() > $self->{num_processors};

	for my $job (@{$self->{trace}->jobs()}) {
		$self->assign_job($job);
	}

	$self->{run_time} = time() - $start;
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
	return $self->sum_flow_time()/scalar $self->{trace}->jobs();
}

sub max_stretch {
	my ($self) = @_;
	return max map {$_->stretch()} @{$self->{trace}->jobs()};
}

sub mean_stretch {
	my ($self) = @_;
	return (sum map {$_->stretch()} @{$self->{trace}->jobs()})/@{$self->{trace}->jobs()};
}

sub cmax {
	my ($self) = @_;
	return max map {$_->cmax()} @{$self->{processors}};
}

sub save_svg {
	my ($self, $svg_filename) = @_;

	open(my $filehandle, "> $svg_filename") or die "unable to open $svg_filename";

	my $cmax = $self->cmax();
	print $filehandle "<svg width=\"800\" height=\"600\">\n";
	my $w_ratio = 800/$cmax;
	my $h_ratio = 600/$self->{num_processors};

	$_->svg($filehandle, $w_ratio, $h_ratio) for (@{$self->{trace}->jobs});

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

sub print_svg {
	my ($self, $svg_filename, $pdf_filename) = @_;

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

sub DESTROY {
	my ($self) = @_;
	for my $processor (@{$self->{processors}}) {
		$processor->remove_all_jobs();
	}
}

1;

