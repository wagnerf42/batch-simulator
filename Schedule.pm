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

	bless $self, $class;
	return $self;
}

sub run {
	my $self = shift;

	for my $job (@{$self->{trace}->jobs}) {
		$self->assign_job($job);
	}
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

1;

