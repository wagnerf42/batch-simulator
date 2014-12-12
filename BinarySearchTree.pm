package BinarySearchTree;
use strict;
use warnings;

use overload '""' => \&_stringification;

=head1 NAME

BinarySearchTree - Binary search tree package with basic generic operations

=head1 METHODS

=over 12

=item new

Returns a new object of the class.

=cut

sub new {
	my ($class, $sentinel) = @_;
	my $self = [$sentinel];
	bless $self, $class;
	return $self;
}

sub new_test {
	my ($class) = @_;
	my $self = [0, 8, 3, 10, 1, 6, undef, 14, undef, undef, 4, 7, undef, undef, 13];
	bless $self, $class;
	return $self;
}

=item add

Adds a new element to the binary search tree.

=cut

sub add {
	my ($self, $item) = @_;
	my $current = 1;
	return $self = [$self->[0], $item] unless $#{$self} > 1;

	while (defined $self->[$current]) {
		$current = ($item < $self->[$current] ? 2*$current : 2*$current + 1);
	}

	$self->[$current] = $item;
	return $current;
}

=item find

Finds an element in the binary search tree.

=cut

sub find {
	my ($self, $item) = @_;
	my $current = 1;

	return unless defined $self->[$current];
	return $self->[$current] unless $#{$self} > 1;

	while (defined $self->[$current]) {
		return ($self->[$current], $current) if $self->[$current] == $item;
		$current = ($item < $self->[$current] ? 2*$current : 2*$current + 1);
	}
}

=item remove_element

Removes an element from the binary search tree.

=cut

sub remove_element {


}

=item remove_index

Removes an element in the binary search tree by index.

=cut

sub remove_index {
	my ($self, $index) = @_;
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

	return "[" . join(' ', @print_order) . "]";
}

1;
