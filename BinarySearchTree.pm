package BinarySearchTree;
use strict;
use warnings;
use parent 'Displayable';

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

sub save_svg {
	my $self = shift;
	my $filename = shift;
	$self->{root}->save_svg($filename);
	return;
}

1;
