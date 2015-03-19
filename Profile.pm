package Profile;

use strict;
use warnings;

use POSIX;
use List::Util qw(min);
use Log::Log4perl qw(get_logger);

use lib 'ProcessorRange/blib/lib', 'ProcessorRange/blib/arch';

use ProcessorRange;

use overload '""' => \&stringification, '<=>' => \&three_way_comparison;

sub new {
	my $class = shift;
	my $starting_time = shift;
	my $duration = shift;
	my $ids = shift;
	my $logger = get_logger('Profile::new');

	my $self = {
		starting_time => $starting_time,
		duration => $duration
	};

	$logger->logconfess("invalid profile duration $self->{duration}") if defined $self->{duration} and $self->{duration} <= 0;

	$self->{processors} = (ref $ids eq 'ProcessorRange') ? $ids : ProcessorRange->new(@$ids);

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
	$self->{duration} = shift if (@_);
	return $self->{duration};
}

sub add_job {
	my $self = shift;
	my $job = shift;
	my $current_time = shift;
	return $self->split_by_job($job, $current_time);
}

sub remove_job {
	my $self = shift;
	my $job = shift;
	$self->{processors}->add($job->assigned_processors_ids());
	return $self;
}

sub split_by_job {
	my $self = shift;
	my $job = shift;

	my @profiles;

	my $middle_start = $self->{starting_time};
	my $middle_end = (defined $self->{duration}) ? min($self->ending_time(), $job->submitted_ending_time()) : $job->submitted_ending_time();
	my $middle_profile = Profile->new($middle_start, $middle_end - $middle_start, $self->{processors}->copy_range());
	$middle_profile->remove_used_processors($job);
	push @profiles, $middle_profile unless $middle_profile->is_fully_loaded();

	unless (defined $self->ending_time() and $job->submitted_ending_time() >= $self->ending_time()) {
		my $end_duration = $self->ending_time() - $job->submitted_ending_time() if defined $self->{duration};
		my $end_profile = Profile->new($job->submitted_ending_time(), $end_duration, $self->{processors}->copy_range());
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

	$self->{processors}->remove($assigned_processors_ids);

	return;
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
	return;
}

my $comparison_function = 'default';
my %comparison_functions = (
	'default' => \&starting_times_comparison,
	'all_times' => \&all_times_comparison
);

sub set_comparison_function {
	$comparison_function = shift;
	return;
}

sub three_way_comparison {
	my $self = shift;
	my $other = shift;
	my $inverted = shift;
	return $comparison_functions{$comparison_function}->($self, $other, $inverted);
}

sub starting_times_comparison {
	my $self = shift;
	my $other = shift;
	my $inverted = shift;

	# Save two calls to the comparison functions if $other is a Profile
	$other = $other->starting_time() if (ref $other eq 'Profile');

	return $other <=> $self->{starting_time} if $inverted;
	return $self->{starting_time} <=> $other;
}

sub all_times_comparison {
	my $self = shift;
	my $other = shift;
	my $inverted = shift;

	my $coef = ($inverted) ? -1 : 1;
	my $ending_time = $self->ending_time();

	if (ref $other eq '') {
		return -$coef if (defined $ending_time) and ($ending_time <= $other);
		return $coef if $self->{starting_time} >= $other;
		return 0;
	}

	return $self->{starting_time} <=> $other->{starting_time} if (ref $other eq 'Profile');

	die 'comparison not implemented';
}

sub DESTROY {
	my $self = shift;
	$self->{processors}->free_allocated_memory() if defined $self->{processors};
	return;
}

1;
