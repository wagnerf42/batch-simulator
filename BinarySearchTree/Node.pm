package BinarySearchTree::Node;
use strict;
use warnings;

use overload '""' => \&_stringification;

use constant {
	LEFT => 0,
	RIGHT => 1
};

sub new {
	my ($class, $content, $father) = @_;

	my $self = {
		content => $content,
		children => [undef, undef],
		father => $father
	};

	bless $self, $class;
	return $self;
}

sub add {
	my ($self, $content) = @_;
	my $current = $self;
	my $direction = $content < $current->content() ? LEFT : RIGHT;
	my $next = $current->{children}->[$direction];

	while (defined $next) {
		$current = $next;
		$direction = $content < $current->content() ? LEFT : RIGHT;
		$next = $current->{children}->[$direction];
	}

	$next = new BinarySearchTree::Node($content, $current);
	$current->{children}->[$direction] = $next;
	return $next;
}

sub find_node {
	my ($self, $key) = @_;
	my $current = $self;

	while (defined $current) {
		last if $current->{content} == $key;
		my $direction = $key < $self->{content} ? LEFT : RIGHT;
		$current = $current->{children}->[$direction];
	}

	return $current;
}

sub remove_node {
	my ($self, $node) = @_;

	if (not defined $node->{children}->[LEFT] and not defined $node->{children}->[RIGHT]) {
		$node->{father}->{children}->[$node->_direction()] = undef;

	} elsif (not defined $self->{children}->[LEFT]) {
		$node->{father}->{children}->[$node->_direction()] = $node->{children}->[RIGHT];
		$node->{children}->[RIGHT]->{father} = $node->{father};

	} elsif (not defined $self->{children}->[RIGHT]) {
		$node->{father}->{children}->[$node->_direction()] = $node->{children}->[LEFT];
		$node->{children}->[LEFT]->{father} = $node->{father};

	} else {
	}
}

sub move_up {
	my ($self, $node) = @_;
	$node
}

sub content {
	my ($self, $content) = @_;
	$self->{content} = $content if defined $content;
	return $self->{content};
}

sub _stringification {
	my ($self) = @_;
	my @children_strings = map {if (defined $_){"$_"} else{""}} @{$self->{children}};
	my $string = join(',', @children_strings);

	#return join(' ', $self->{children}->[LEFT], $self->{content}, $self->{children}->[RIGHT]);
	return $self->{content} . "[$string]";
	
}

sub _last_child_index {
	my ($self, $index, $direction) = @_;
	my $next_index = $index;

	while (defined $self->[$next_index]) {
		$index = $next_index;
		$next_index = $index*2 + 1 + $direction;
	}

	return $index;
}

sub _direction {
	my ($self) = @_;
	return ($self == $self->{father}->{children}->[LEFT] ? LEFT : RIGHT) if defined $self->{father};
}

=back
=cut

1;
