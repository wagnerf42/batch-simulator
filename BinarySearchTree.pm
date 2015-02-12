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

sub find_node {
	my $self = shift;
	my $key = shift;
	return $self->{root}->find_node($key);
}

sub nodes_loop2 {
	my $self = shift;
	my $start_key = shift;
	my $end_key = shift;
	my $routine = shift;

	$start_key = $self->{min_valid_key} unless defined $start_key;

	$self->{root}->nodes_loop2($start_key, $end_key, $routine);
	return;
}

sub nodes_loop {
	my $self = shift;
	my $start_key = shift;
	my $end_key = shift;
	my $routine = shift;

	$start_key = $self->{min_valid_key} unless defined $start_key;

	my @stack;
	push @stack, [$self->{root}, LEFT];
	push @stack, [$self->{root}, NONE];
	push @stack, [$self->{root}, RIGHT];

	my $node = BinarySearchTree::Node::next_node_between($start_key, $end_key, 1, \@stack);
	return unless defined $node;
	my $continue;
	do {
		$continue = $routine->($node->get_content());
		$node = BinarySearchTree::Node::next_node_between($start_key, $end_key, 0, \@stack) if $continue;
	} while( defined $node and $continue );

	return;
}

sub save_svg {
	my $self = shift;
	my $filename = shift;
	$self->{root}->save_svg($filename);
	return;
}

1;
