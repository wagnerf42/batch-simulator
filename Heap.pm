package Heap;
use strict;
use warnings;

=head1 NAME

Heap - Heap implementation with generic manipulation routines

=head2 METHODS

=over 12

=item new(sentinel)

Returns a new object of the Heap class.

The sentinel is an object or scalar that is smaller than any other object or
scalar that the heap can store.

=cut

sub new {
	my $class = shift;
	my $self = {};

	my $sentinel = shift;
	$self->{elements} = [ $sentinel ];

	bless $self, $class;
	return $self;
}

=item retrieve()

Returns the smallest object or scalar stored in the heap.

This routine removes the first element in the list and puts in its place the
last element. Then it fixes the heap structure by moving it down as necessary.

=cut

sub retrieve {
	my $self = shift;

	return unless defined $self->{elements}->[1];
	my $min_element = $self->{elements}->[1];
	my $last_element = pop @{$self->{elements}};
	return $min_element unless defined $self->{elements}->[1]; #no one left, no order to fix

	$self->{elements}->[1] = $last_element;
	$self->_move_first_down();

	return $min_element;
}

sub retrieve_all {
	my $self = shift;
	return unless defined $self->{elements}->[1];

	my @min_elements = ($self->retrieve());

	while (defined $self->{elements}->[1] and $self->{elements}->[1] == $min_elements[0]) {
		push @min_elements, $self->retrieve();
	}

	return @min_elements;
}

sub not_empty {
	my $self = shift;
	return defined $self->{elements}->[1];
}

sub next_element {
	my ($self) = @_;
	return $self->{elements}->[1];
}

=item add(element)

Adds a new element to the heap structure.

The new element is added at the end of the structure. Then it is moved up as
necessary to preserve the priority order between the elements in the heap.

=cut

sub add {
	my $self = shift;
	my $element = shift;

	push @{$self->{elements}}, $element;

	$self->_move_last_up();
	return;
}

sub _move_last_up {
	my $self = shift;

	my $current_position = $#{$self->{elements}};
	my $father = int $current_position / 2;

	while ($self->{elements}->[$current_position] < $self->{elements}->[$father]) {
		$self->_exchange($current_position, $father);

		$current_position = $father;
		$father = int $father / 2;
	}
	return;
}

sub _move_first_down {
	my $self = shift;

	my $current_position = 1;
	my $min_child_index = $self->_find_min_child($current_position);
	while ((defined $min_child_index) and ($self->{elements}->[$min_child_index] < $self->{elements}->[$current_position])) {
		$self->_exchange($current_position, $min_child_index);
		$current_position = $min_child_index;
		$min_child_index = $self->_find_min_child($current_position);
	}
	return;
}

sub _exchange {
	my $self = shift;
	my $a = shift;
	my $b = shift;
	($self->{elements}->[$a], $self->{elements}->[$b]) = ($self->{elements}->[$b], $self->{elements}->[$a]);
	return;
}

sub _find_min_child {
	my $self = shift;
	my $index = shift;
	my ($child1, $child2) = (2*$index, 2*$index+1);

	return unless defined $self->{elements}->[$child1];
	return $child1 unless defined $self->{elements}->[$child2];

	if ($self->{elements}->[$child1] < $self->{elements}->[$child2]) {
		return $child1;
	} else {
		return $child2;
	}
}

1;
