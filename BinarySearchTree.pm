package BinarySearchTree;
use strict;
use warnings;

use overload '""' => \&_stringification;

use constant {
	RIGHT => 0,
	LEFT => -1
};

=head1 NAME

BinarySearchTree - Binary search tree package with basic generic operations

=head2 METHODS

=over 12

=item new(sentinel)

The sentinel is an element that will always be valued as smaller than any other
element in the tree.

=cut

sub new {
	my ($class, $sentinel) = @_;
	my $self = [$sentinel];
	bless $self, $class;
	return $self;
}

=item add

Adds a new element to the binary search tree.

The basic algorithm is to go through the tree trying to find the best leaf for
the new element. Note that adding elements may unbalance the tree if elements
are already sorted.

=cut

sub add {
	my ($self, $item) = @_;
	my $current = 1;

	while (defined $self->[$current]) {
		$current = ($item < $self->[$current] ? 2*$current : 2*$current + 1);
	}

	$self->[$current] = $item;
	return $current;
}

=item find

Finds an element in the binary search tree.

This routine receives an actual element and looks for a similar one in the
tree. Depending on the operators supported by the elements, a key may be used
to compare to elements, instead of an element of the same type.

=cut

sub find {
	my ($self, $item) = @_;
	my $current = 1;

	return unless defined $self->[$current];
	return $self->[$current] unless $#{$self} > 1;

	while (defined $self->[$current]) {
		last if $self->[$current] == $item;
		$current = ($item < $self->[$current] ? 2*$current : 2*$current + 1);
	}

	return ($self->[$current], $current);

}

=item remove_element

Removes an element from the binary search tree.

=cut

sub remove_element {
	my ($self, $item) = @_;
	my ($found_item, $found_index) = $self->find($item);
	$self->remove_index($found_index) if defined $found_index;
}

=item remove_index

Removes an element in the binary search tree by index.

=cut

sub remove_index {
	my ($self, $index) = @_;
	my ($left_child, $right_child) = (2*$index, 2*$index + 1);

	if (not defined $self->[$left_child] and not defined $self->[$right_child]) {
		$self->[$index] = undef;
		return;

	} elsif (not defined $self->[$left_child]) {
		$self->move_up($right_child, LEFT);

	} elsif (not defined $self->[$right_child]) {
		$self->move_up($left_child, RIGHT);

	} else {
		my $direction = int rand(2);
		my $last_child_index = $self->_last_child_index(2*$index + $direction, $direction);

		$self->[$index] = $self->[$last_child_index];
		$self->remove_index($last_child_index);
	}

}

=item move_up

Moves elements of the tree up.

This subroutine is used during the removal of elements.

=cut

sub move_up {
	my ($self, $position, $direction) = @_;
	my $target_offset = $direction + $position%2;
	my $target_position = int $position/2 + $target_offset;

	return unless defined $self->[$position];

	print "item=" . $self->[$position] . ", position=$position, target_position=$target_position, direction=$direction, offset=$target_offset\n";

	$self->[$target_position] = $self->[$position];
	$self->[$position] = undef;

	# We need to move first the child that is on the side of the direction
	$self->move_up($position*2 + $direction + 1, $direction);
	$self->move_up($position*2 + abs $direction, $direction);
}

=item balance

Returns the balance level of the binary search tree.

=cut

sub balance {
	my ($self) = @_;
}

sub _stringification {
	my ($self) = @_;
	my $current = 1;
	my @stack;
	my @print_order;
	my @raw_print_order = map {defined $_ ? $_ : 'undef'} @{$self};

	return unless defined $self->[1];

	while ($#stack >= 0 or defined $self->[$current]) {
		while (defined $self->[$current]) {
			push @stack, $current;
			$current *= 2;
		}

		$current = pop @stack;
		push @print_order, $self->[$current];
		$current = $current*2 + 1;
	}

	return "[" . join(' ', @print_order) . "] -> [" . join(' ', @raw_print_order) . "]";
}

sub _last_child_index {
	my ($self, $index, $direction) = @_;
	my $next_index = $index;

	while (defined $self->[$next_index]) {
		$index = $next_index;
		$next_index = $index*2 + 1 + $direction;
	}

	return $index;
}

=back
=cut

1;
