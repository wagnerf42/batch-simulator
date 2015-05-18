package FreeSpace;

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use List::Util qw(min);

use BinarySearchTree::Node2;

use lib 'ProcessorRange/blib/lib', 'ProcessorRange/blib/arch';

use ProcessorRange;
use overload
	'""' => \&stringify;

my $count = 0;
sub new {
	my $class = shift;
	my $start_time = shift;
	my $duration = shift;
	my $processor_range = shift;

	my $self = {
		starting_time => $start_time,
		duration => $duration,
		processors => undef
	};

	$self->{processors} = (ref $processor_range eq 'ProcessorRange') ? $processor_range : ProcessorRange->new(@$processor_range);
	$self->{id} = $count;
	$count++;

	bless $self, $class;
	return $self;
}

sub stringify {
	my $self = shift;
	return "{id=$self->{id},s=$self->{starting_time},d=infini,p=$self->{processors}" if ($self->{duration} == "inf");
	return "{id=$self->{id},s=$self->{starting_time},d=$self->{duration},p=$self->{processors}";
}

sub starting_time {
	my $self = shift;
	$self->{starting_time} = shift if @_;
	return $self->{starting_time};
}

sub ending_time {
	my $self = shift;
	my $infinity = 0 + "inf";
	return ($self->{duration} == $infinity) ? $infinity : ($self->{starting_time} + $self->{duration});
}

sub processors {
	my $self = shift;
	my $processors = shift;

	$self->{processors} = $processors if defined $processors;

	return $self->{processors};
}

sub processors_ids {
	my $self = shift;
	return $self->{processors}->processors_ids();
}

sub duration {
	my $self = shift;
	my $duration = shift;

	return $self->{duration};
}

sub svg {
	my ($self, $fh, $w_ratio, $h_ratio, $last_time) = @_;
	print STDERR "$self\n";
	my @svg_colors = qw(red green blue purple orange saddlebrown mediumseagreen darkolivegreen darkred dimgray mediumpurple midnightblue olive chartreuse darkorchid hotpink lightskyblue peru goldenrod mediumslateblue orangered darkmagenta darkgoldenrod mediumslateblue);

	$self->{processors}->ranges_loop(
		sub {
			my ($start, $end) = @_;

			#rectangle
			my $x = $self->{starting_time} * $w_ratio;
			my $duration;
			if ($self->{duration}!="inf") {
				$duration = $self->{duration};
			} else {
				print STDERR "hello $last_time\n";
				$duration = 100/$w_ratio + $last_time - $self->{starting_time};
			}
			my $w = $duration * $w_ratio;

			my $y = $start * $h_ratio;
			my $h = $h_ratio * ($end - $start + 1);
			my $color = $svg_colors[$self->{id} % @svg_colors];
			my $sw = min($w_ratio, $h_ratio) / 10;
			print $fh "\t<rect x=\"$x\" y=\"$y\" width=\"$w\" height=\"$h\" style=\"fill:$color;fill-opacity:0.2;stroke:black;stroke-width:$sw\"/>\n";
			return 1;
		}
	);
	return;
}

1;
