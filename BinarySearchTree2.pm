package BinarySearchTree2;
use strict;
use warnings;
use parent 'Displayable';

use Data::Dumper qw(Dumper);
use Carp;

use BinarySearchTree::Node2;

sub new {
	my $class = shift;
	my $sentinel = shift;

	my $self = {
		root => BinarySearchTree::Node2->new($sentinel, 'SENTINEL'),
		min_valid_key => shift
	};

	bless $self, $class;
	return $self;
}

sub add_content {
	my $self = shift;
	my $key = shift;
	my $content = shift;

	# TODO Remove this check eventually
	confess "already here" if $self->{root}->find_node($key);

	return $self->{root}->add($key, $content);
}

sub remove_content {
	my $self = shift;
	my $content = shift;

	my $node = $self->{root}->find_node($content);
	$node->remove() if defined $node;
	return;
}

sub remove_node {
	my $node = shift;
	return $node->remove();
}

sub find_node {
	my $self = shift;
	my $key = shift;
	return $self->{root}->find_node($key);
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

sub display_subtrees {
	my $self = shift;
	my @nodes = ($self->{root});
	while (@nodes) {
		my $node = shift @nodes;
		my $key = $node->get_key();
		$key = join(',', @{$key}) if ref $key eq 'ARRAY';
		print "count tree for $key is :\n";
		my $subtree = $node->get_tree();
		$subtree->tycat() if defined $subtree;
		push @nodes, $_ for $node->children();
	}
	return;
}

1;
