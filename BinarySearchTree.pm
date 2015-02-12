package BinarySearchTree;
use strict;
use warnings;
use parent 'Displayable';

use Data::Dumper qw(Dumper);

use BinarySearchTree::Node;

sub new {
	my $class = shift;
	my $sentinel = shift;
	my $minimal_valid_key = shift;

	my $self = {
		root => new BinarySearchTree::Node($sentinel, undef),
		minimal_valid_key => $minimal_valid_key
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

sub nodes_loop {
	my $self = shift;
	my $start_key = shift;
	$start_key = $self->{minimal_valid_key} unless defined $start_key;
	my $end_key = shift;
	my $routine = shift;

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
