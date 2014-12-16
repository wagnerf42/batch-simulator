package BinarySearchTree;
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use BinarySearchTree::Node;

use overload '""' => \&_stringification;

sub new {
	my ($class, $sentinel) = @_;

	my $self = {
		root => new BinarySearchTree::Node($sentinel, undef)
	};

	bless $self, $class;
	return $self;
}

sub add {
	my ($self, $content) = @_;
	return $self->{root}->add($content);
}

sub find_node {
	my ($self, $key) = @_;
	return $self->{root}->find_node($key);
}

sub _stringification {
	my ($self) = @_;
	return "$self->{root}";
}

sub remove_node {
	my ($self, $node) = @_;
	$self->{root}->remove_node($node);
}

1;
