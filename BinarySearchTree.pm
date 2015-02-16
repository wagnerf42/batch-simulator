package BinarySearchTree;
use strict;
use warnings;
use parent 'Displayable';

use Data::Dumper qw(Dumper);

use BinarySearchTree::Node;

use constant {
	LEFT => 0,
	RIGHT => 1,
	NONE => 2
};

sub new {
	my $class = shift;
	my $sentinel = shift;

	my $self = {
		root => new BinarySearchTree::Node($sentinel, undef),
		min_valid_key => shift
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
	my $self = shift;
	my $content = shift;

	my $node = $self->{root}->find_node($content);
	$node->remove();
	return;
}

sub find {
	my $self = shift;
	my $key = shift;
	return $self->{root}->find_node($key)->content();
}

sub nodes_loop {
	my $self = shift;
	my $start_key = shift;
	my $end_key = shift;
	my $routine = shift;

	$start_key = $self->{min_valid_key} unless defined $start_key;
	$self->{root}->nodes_loop($start_key, $end_key, $routine);
	return;
}

sub save_svg {
	my $self = shift;
	my $filename = shift;
	$self->{root}->save_svg($filename);
	return;
}

1;
