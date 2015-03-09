package BinarySearchTree;
use strict;
use warnings;
use parent 'Displayable';

use Data::Dumper qw(Dumper);
use Carp;

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

sub add_content {
	my $self = shift;
	my $content = shift;

	my $node = $self->{root}->find_node($content);

	confess "$content found in $node->{content}" if defined $node; # check to see if we are not inserting duplicated content

	return $self->{root}->add($content);
}

sub remove_content {
	my $self = shift;
	my $content = shift;

	my $node = $self->{root}->find_node($content);
	$node->remove();
	return;
}

sub remove_node {
	my $node = shift;
	return $node->remove();
}

sub find_content {
	my $self = shift;
	my $key = shift;
	my $node = $self->{root}->find_node($key);
	return $node->content() if defined $node;
	return;
}

sub find_previous_content {
	my $self = shift;
	my $key = shift;
	my $previous_node = $self->{root}->find_previous_node($key);
	return $previous_node->content() if defined $previous_node and $previous_node->content() != $self->{root}->content(); # it is possible that the sentinel is the previous content
	return;
}

sub find_closest_content {
	my $self = shift;
	my $key = shift;
	return $self->{root}->find_closest_node($key)->content();
}

##CAREFUL WITH THIS SPICY STUFF
##it does everything touching the given times
##TODO: have two separate loops ?? strict and loose ??
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
