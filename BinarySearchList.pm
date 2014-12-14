package BinarySearchList;

use strict;
use warnings;

use Data::Dumper qw(Dumper);

use overload '""' => \&_stringification;

=head1 NAME

BinarySearchList - Binary search module with some basic operations

=head2 METHODS

=over 12

=item new(payload, sorted)

Returns a new class object.

The payload may be defined or not. If it is defined, it may be sorted or not,
depending on the parameter.

=cut

sub new {
	my ($class, $payload, $sorted) = @_;

	$payload = [] unless defined $payload;
	@{$payload} = sort {$a <=> $b} @{$payload} unless $sorted;

	my $self = {
		payload => $payload
	};

	bless $self, $class;
	return $self;
}

=item add

Adds a new item to the binary search list.

The item should be of the same type of the other elements of the list.  The
first thing that the routines does is search for an item similar to the one
being added. After it either finds it or not, the new item is added in a valid
position, although it is probably not possible to determine in which order
between the items that have the same key.

=cut

sub add {
	my ($self, $item, $min, $max) = @_;
	my $insert_position = $self->find($item, $min, $max);
	splice @{$self->{payload}}, $insert_position, 0, $item;
}

=item find(item, min, max)

Returns the first item found that is valid.

This routine will field the first item found that is valid according to the ==
operator which the items inside the payload must support.  Items inside the
payload must also support the < and > operators. The min and max parameters are
optional. They can be used to limit the search inside a certain range instead
of searching in the whole payload.

=cut

sub find {
	my ($self, $item, $min, $max) = @_;
	$min = 0 unless defined $min;
	$max = $#{$self->{payload}} unless defined $max;

	while ($max >= $min) {
		my $mid = _midpoint($min, $max);
		return $mid if ($self->{payload}->[$mid] == $item);

		if ($self->{payload}->[$mid] > $item) {
			$max = $mid - 1;
		} else {
			$min = $mid + 1;
		}
	}

	return $min;
}

=item find_first(item, min, max)

Return the first item that is valid.

The difference between this routine and find is that this one makes sure that
it returns the smallest item inside the payload that is valid, and
not the first one found. The other characteristics are similar.

=cut

sub find_first {
	my ($self, $item, $min, $max) = @_;
	$min = 0 unless defined $min;
	$max = $#{$self->{payload}} unless defined $max;

	while ($max >= $min) {
		my $mid = _midpoint($min, $max);

		die unless $min >= 0 and $min < $max;

		if ($self->{payload}->[$mid] < $item) {
			$min = $mid + 1;
		} else {
			$max = $mid;
		}
	}

	return $self->{payload}->[$min] if ($max == $min and $self->{payload}->[$min] == $item);
}

sub _midpoint {
	my ($min, $max) = @_;
	return int(($min + $max)/2);
	#return $min + (($max - $min)/2);
}

sub _stringification {
	my ($self) = @_;
	return "[" . join(' ', @{$self->{payload}}) . "]";
}

=back

=cut

1;
