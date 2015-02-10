package BinarySearchTree;
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use BinarySearchTree::Node;

sub new {
	my $class = shift;
	my $sentinel = shift;

	my $self = {
		root => new BinarySearchTree::Node($sentinel, undef)
	};

	bless $self, $class;
	return $self;
}

sub add {
	my $self = shift;
	my $content = shift;
	return $self->{root}->add($content);
}

sub remove {
	my $node = shift;
	$node->remove();
}

sub find_node {
	my $self = shift;
	my $key = shift;
	return $self->{root}->find_node($key);
}

sub create_dot {
	my $self = shift;
	$self->{root}->create_dot();
}

1;
