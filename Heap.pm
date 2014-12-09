package Heap;
use strict;
use warnings;

sub new {
	my $class = shift;
	my $self = {};

	my $sentinel = shift;
	$self->{elements} = [ $sentinel ];

	bless $self, $class;
	return $self;
}

sub retrieve {
	my $self = shift;

	return unless defined $self->{elements}->[1];
	my $min_element = $self->{elements}->[1];
	my $last_element = pop @{$self->{elements}};
	return $min_element unless defined $self->{elements}->[1]; #no one left, no order to fix

	$self->{elements}->[1] = $last_element;
	$self->move_first_down();

	return $min_element;
}

sub add {
	my $self = shift;
	my $element = shift;

	push @{$self->{elements}}, $element;

	$self->move_last_up();
}

sub move_last_up {
	my $self = shift;

	my $current_position = $#{$self->{elements}};
	my $father = int $current_position / 2;

	while ($self->{elements}->[$current_position] < $self->{elements}->[$father]) {
		$self->exchange($current_position, $father);

		$current_position = $father;
		$father = int $father / 2;
	}
}

sub move_first_down {
	my $self = shift;

	my $current_position = 1;
	my $min_child_index = $self->find_min_child($current_position);
	while ((defined $min_child_index) and ($self->{elements}->[$min_child_index] < $self->{elements}->[$current_position])) {
		$self->exchange($current_position, $min_child_index);
		$current_position = $min_child_index;
		$min_child_index = $self->find_min_child($current_position);
	}
}

sub exchange {
	my $self = shift;
	my ($a, $b) = @_;
	($self->{elements}->[$a], $self->{elements}->[$b]) = ($self->{elements}->[$b], $self->{elements}->[$a]);
}

sub find_min_child {
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
