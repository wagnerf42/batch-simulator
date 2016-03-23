package ProcessorRange;

use 5.0;

use strict;
use warnings;

use Carp;
use POSIX qw(floor ceil);
use List::Util qw(min max sum);
use Data::Dumper;

use Platform;

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration use ProcessorRange ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our $VERSION = '0.01';

require XSLoader;
XSLoader::load('ProcessorRange', $VERSION);

use overload '""' => \&stringification;

sub new {
	my $class = shift;
	my $self;

	if (@_ == 1) {
		my $original_range = shift;
		$self = copy_range($original_range);
	} else {
		die unless (@_ % 2) == 0;
		my $limits = [@_];
		$self = new_range($limits);
	}

	return $self;
}

sub remove {
	my $self = shift;
	my $other = shift;

	my $inverted_other = $other->invert($self->get_last());
	$self->intersection($inverted_other);
	$inverted_other->free_allocated_memory();

	return;
}

sub pairs {
	my $self = shift;
	my @pairs;

	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			push @pairs, [$start, $end];
			return 1;
		}
	);

	return @pairs;
}

sub check_ok {
	my $self = shift;
	my $last_end = -1;

	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;

			die "invalid range $self: repeated cpu ($last_end)" if $start == $last_end;
			die "invalid range $self: end < start ($end < $start)" if $end < $start;
			die "invalid range $self: start not defined" unless defined $end;
			die "invalid range $self: end not defined" unless defined $end;

			$last_end = $end;
			return 1;
		}
	);

	return;
}

sub processors_ids {
	my $self = shift;
	my $processors_ids = shift;
	my @ids;

	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			push @ids, ($start..$end);
			return 1;
		}
	);

	return @ids;
}

sub stringification {
	my $self = shift;
	my @strings;

	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			push @strings, "[$start-$end]";
			return 1;
		}
	);

	return join(' ', @strings);
}

sub sort_and_fuse_contiguous_ranges {
	my $ranges = shift;

	my @sorted_ranges = sort {$a->[1] <=> $b->[1]} @{$ranges};
	my @remaining_ranges;

	push @remaining_ranges, (@{shift @sorted_ranges});

	for my $range (@sorted_ranges) {
		if ($range->[0] == $remaining_ranges[-1] + 1) {
			$remaining_ranges[-1] = $range->[1];
		} else {
			push @remaining_ranges, @$range;
		}
	}

	return \@remaining_ranges;
}

1;

