package BinarySearchTree::Node;
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Scalar::Util qw(refaddr);
use Carp qw(confess);

use overload '""' => \&_stringification, '==' => \&_is_equal;

use constant {
	LEFT => 0,
	RIGHT => 1
};

sub new {
	my ($class, $content, $father) = @_;

	my $self = {
		content => $content,
		children => [undef, undef],
		father => $father
	};

	bless $self, $class;
	return $self;
}

sub add {
	my ($self, $content) = @_;
	my $current = $self;
	my $direction = $content < $current->content() ? LEFT : RIGHT;
	my $next = $current->{children}->[$direction];

	while (defined $next) {
		$current = $next;
		$direction = $content < $current->content() ? LEFT : RIGHT;
		$next = $current->{children}->[$direction];
	}

	$next = new BinarySearchTree::Node($content, $current);
	$current->{children}->[$direction] = $next;
	return $next;
}

sub find_node {
	my ($self, $key) = @_;
	my $current = $self;

	while (defined $current) {
		last if $current->{content} == $key;
		my $direction = ($key < $current->{content} ? LEFT : RIGHT);
		$current = $current->{children}->[$direction];
	}

	return $current;
}

sub remove_node {
	my ($self, $node) = @_;

	if (not defined $node->{children}->[LEFT] and not defined $node->{children}->[RIGHT]) {
		$node->{father}->{children}->[$node->_direction()] = undef;

	} elsif (not defined $node->{children}->[LEFT]) {
		$node->{father}->{children}->[$node->_direction()] = $node->{children}->[RIGHT];
		$node->{children}->[RIGHT]->{father} = $node->{father};

	} elsif (not defined $node->{children}->[RIGHT]) {
		$node->{father}->{children}->[$node->_direction()] = $node->{children}->[LEFT];
		$node->{children}->[LEFT]->{father} = $node->{father};

	} else {
		my $direction = int rand(2);
		my $last_child = $self->_last_child($node->{children}->[$direction], 1 - $direction);
		$node->{content} = $last_child->{content};
		$self->remove_node($last_child);
	}
}

sub content {
	my ($self, $content) = @_;
	$self->{content} = $content if defined $content;
	return $self->{content};
}

sub _stringification {
	my ($self) = @_;
	my @children_strings = map {if (defined $_) {"$_"} else {""}} @{$self->{children}};
	my $string = join(',', @children_strings);

	return $self->{content} . "[$string]";
}

sub _last_child {
	my ($self, $node, $direction) = @_;
	while (defined $node->{children}->[$direction]) {
		$node = $node->{children}->[$direction];
	}
	return $node;
}

sub _direction {
	my ($self) = @_;
	my $children = $self->{father}->{children};

	return LEFT if (defined $children->[LEFT] and $self == $children->[LEFT]);
	return RIGHT;
}

sub _is_equal {
	my ($self, $other) = @_;
	return refaddr($self) == refaddr($other);
}

1;
