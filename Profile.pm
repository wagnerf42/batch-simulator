package Profile;

use Carp;

use ProcessorRange;

use strict;
use warnings;
use POSIX;
use overload '""' => \&stringification, '<=>' => \&three_way_comparison;

use List::Util qw(min);

#a profile objects encodes a set of free processors at a given time

sub new {
	my $class = shift;
	my $self = {};
	$self->{starting_time} = shift;
	my $ids = shift;
	$self->{duration} = shift;
	confess "negative profile duration $self->{duration}" if defined $self->{duration} and $self->{duration} <= 0;

	if (ref $ids eq "ProcessorRange") {
		$self->{processors} = $ids;
	} else {
		$self->{processors} = ProcessorRange->new(@$ids);
	}

	bless $self, $class;
	return $self;
}

sub stringification {
	my $self = shift;
	return "[$self->{starting_time} ; ($self->{processors}) ; $self->{duration}]" if defined $self->{duration};
	return "[$self->{starting_time} ; ($self->{processors}) ]";
}

sub processors {
	my $self = shift;
	return $self->{processors};
}

sub processors_ids {
	my $self = shift;
	return $self->{processors}->processors_ids();
}

sub duration {
	my $self = shift;
	if (@_) {
		$self->{duration} = shift;
		confess "negative profile duration $self->{duration}" if defined $self->{duration} and $self->{duration} <= 0;
	}
	return $self->{duration};
}

#returns two or one profile if it is split or not by job insertion
sub add_job {
	my $self = shift;
	my $job = shift;
	my $current_time = shift;

	confess unless defined $current_time;
	confess if $self->{starting_time} >= $job->ending_time_estimation($current_time);
	confess "putting job starting at ".$job->starting_time()." on profile $self" if (defined $self->ending_time() and $self->ending_time() <= $job->starting_time());

	return $self->split($job, $current_time);
}

#free some processors by canceling a job
sub remove_job {
	my $self = shift;
	my $job = shift;
	$self->{processors}->add($job->assigned_processors_ids());
	return $self;
}

#TODO : not very pretty ?
#TODO : documentation
sub split {
	my $self = shift;
	my $job = shift;
	my $current_time = shift;

	my @profiles;
	my $middle_start = $self->{starting_time};
	my $middle_end;

	if (defined $self->{duration}) {
		$middle_end = min($self->ending_time(), $job->ending_time_estimation($current_time));
	} else {
		$middle_end = $job->ending_time_estimation($current_time);
	}

	my $middle_duration = $middle_end - $middle_start if defined $middle_end;
	my $middle_profile = new Profile($middle_start, new ProcessorRange($self->{processors}), $middle_duration);
	$middle_profile->remove_used_processors($job);
	push @profiles, $middle_profile unless $middle_profile->is_fully_loaded();

	if ((not defined $self->ending_time()) or ($job->ending_time_estimation($current_time) < $self->ending_time())) {
		my $end_duration;
		if (defined $self->{duration}) {
			$end_duration = $self->ending_time() - $job->ending_time_estimation($current_time);
		}
		my $end_profile = new Profile($job->ending_time_estimation($current_time), new ProcessorRange($self->{processors}), $end_duration);
		push @profiles, $end_profile;
	}
	return @profiles;
}

sub is_fully_loaded {
	my $self = shift;
	return $self->{processors}->is_empty();
}

sub remove_used_processors {
	my $self = shift;
	my $job = shift;
	my $assigned_processors_ids = $job->assigned_processors_ids();
	confess unless defined $assigned_processors_ids;
	$self->{processors}->remove($assigned_processors_ids);
}

sub starting_time {
	my $self = shift;
	$self->{starting_time} = shift if @_;
	return $self->{starting_time};
}

sub ending_time {
	my $self = shift;
	return unless defined $self->{duration};
	return $self->{starting_time} + $self->{duration};
}

sub ends_after {
	my $self = shift;
	my $time = shift;
	return 1 unless defined $self->{duration};
	return ($self->{duration} + $self->{starting_time} > $time);
}

sub svg {
	my ($self, $fh, $w_ratio, $h_ratio, $current_time, $index) = @_;

	my @svg_colors = qw(red green blue purple orange saddlebrown mediumseagreen darkolivegreen darkred dimgray mediumpurple midnightblue olive chartreuse darkorchid hotpink lightskyblue peru goldenrod mediumslateblue orangered darkmagenta darkgoldenrod mediumslateblue);

	$self->{processors}->ranges_loop(
		sub {
			my ($start, $end) = @_;

			#rectangle
			my $x = $self->{starting_time} * $w_ratio;
			my $w = $self->{duration} * $w_ratio;

			my $y = $start * $h_ratio;
			my $h = $h_ratio * ($end - $start + 1);
			my $color = $svg_colors[$index % @svg_colors];
			my $sw = min($w_ratio, $h_ratio) / 10;
			print $fh "\t<rect x=\"$x\" y=\"$y\" width=\"$w\" height=\"$h\" style=\"fill:$color;fill-opacity:0.2;stroke:black;stroke-width:$sw\"/>\n";
			return 1;
		}
	);
}

sub three_way_comparison {
	my $self = shift;
	my $other = shift;
	my $inverted = shift;

	return $other <=> $self->{starting_time} if $inverted;
	return $self->{starting_time} <=> $other;
}

sub loose_comparison {
	my $self = shift;
	my $other = shift;

	# Comparing two integers
	return $self <=> $other unless (ref $self eq 'Profile');

	# Comparing self and a integer
	my $ending_time = $self->ending_time();

	return -1 if (defined $ending_time) and ($ending_time < $other);
	return 1 if $self->{starting_time} > $other;
	return 0;
}

1;
