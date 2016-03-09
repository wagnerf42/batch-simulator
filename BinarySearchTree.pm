package BinarySearchTree;
use strict;
use warnings;
use parent 'Displayable';

use Data::Dumper qw(Dumper);
use Carp;

use BinarySearchTree::Node;
use POSIX;

sub new {
	my $class = shift;
	my $sentinel = shift;

	my $self = {
		root => BinarySearchTree::Node->new($sentinel, undef, DBL_MAX),
		min_valid_key => shift
	};

	bless $self, $class;
	return $self;
}

sub add_content {
	my $self = shift;
	my $content = shift;

	my $node = $self->{root}->find_node($content);
	die "found duplicate for $content" if defined $node;

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
