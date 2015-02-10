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

sub find_node {
	my $self = shift;
	my $content = shift;
	return $self->{root}->find_node($content);
}

sub create_dot {
	my $self = shift;
	$self->{root}->create_dot();
	return;
}

1;
