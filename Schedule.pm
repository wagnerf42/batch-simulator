package Schedule;
use strict;
use warnings;

use Processor;
use List::Util qw(max);

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

	# Make sure the trace is clean
	$self->{trace}->reset();

	bless $self, $class;
	return $self;
}

sub run {
	my $self = shift;

	die "not enough processors (we need " . $self->{trace}->needed_cpus() . ", we have " . $self->{num_processors} . ")" if $self->{trace}->needed_cpus() > $self->{num_processors};

	my $start = time();

	for my $job (@{$self->{trace}->jobs}) {
		$self->assign_job($job);
	}

	$self->{run_time} = time() - $start;

	return {
		cmax => $self->cmax(),
		run_time => $self->{run_time}
	};
}

sub run_time {
	my $self = shift;

	return $self->{run_time};
}

sub print {
	my $self = shift;
	print "Printing schedule\n";
	$_->print_jobs() for @{$self->{processors}};
}

sub cmax {
	my $self = shift;
	return max map {$_->cmax()} @{$self->{processors}};
}

sub save_svg {
	my $self = shift;
	my $svg_filename = shift;
	my $pdf_filename = shift;

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
	my $self = shift;
	my $user = $ENV{"USER"};
	my $dir = "/tmp/$user";
	mkdir $dir unless -f $dir;
	$self->save_svg("$dir/$file_count.svg");
	`tycat $dir/$file_count.svg`;
	$file_count++;
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

sub DESTROY {
	my $self = shift;
	for my $processor (@{$self->{processors}}) {
		$processor->remove_all_jobs();
	}
}

1;

