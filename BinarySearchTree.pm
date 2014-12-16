package BinarySearchTree;
use strict;
use warnings;

use overload '""' => \&_stringification;

use constant {
	LEFT => 0,
	RIGHT => 1
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
	my ($class, $payload) = @_;

	my $self = {
		payload => $payload,
		children => []
	};

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
	my $current = $self;
	my $direction = $item < $current->payload() ? LEFT : RIGHT;
	my $next = $current->{children}->[$direction];

	while (defined $next) {
		$current = $next;
		$direction = $item < $current->payload() ? LEFT : RIGHT;
		$next = $current->{children}->[$direction];
	}

	$next = new BinarySearchTree($item);
	$current->{children}->[$direction] = $next;
	return $next;
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

=item payload

Returns the payload contained in a BinarySearchTree object or set a new one.

=cut

sub payload {
	my ($self, $payload) = @_;
	$self->{payload} = $payload if defined $payload;
	return $self->{payload};
}

sub _stringification {
	my ($self) = @_;
	my $left_child_string = defined $self->{children}->[LEFT] ? $self->{children}->[LEFT] : "u";
	my $right_child_string = defined $self->{children}->[RIGHT] ? $self->{children}->[RIGHT] : "u";

	#return join(' ', $self->{children}->[LEFT], $self->{payload}, $self->{children}->[RIGHT]);
	return $self->{payload} . " [" . $left_child_string . " " . $right_child_string . "]";
	
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
