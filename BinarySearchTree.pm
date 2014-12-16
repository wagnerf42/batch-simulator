package BinarySearchTree;
use strict;
use warnings;

use BinarySearchTree::Node;

use overload '""' => \&_stringification;

sub new {
	my ($class, $sentinel, $key_type) = @_;

	my $self = {
		root => new BinarySearchTree::Node($sentinel, undef),
		key_type => $key_type
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
	die unless (ref $key) eq $self->{key_type};
	return $self->{root}->find_node($key);
}

sub find_content {
	my ($self, $key) = @_;
	my $node = $self->{root}->find_node($key);
	return unless defined $node;
	return $node->content();
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
