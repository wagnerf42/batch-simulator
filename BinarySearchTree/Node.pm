package Node;

use Data::Dumper;
use Scalar::Util qw(refaddr);

use warnings;
use strict;
use constant {
	LEFT => 0,
	RIGHT => 1,
	NONE => 2
};


sub new {
	my $class = shift;
	my $self = {
		content => shift,
		children => [undef, undef], #left 0, right 1
		father => shift
	};

	bless $self, $class;
	return $self;
}

sub add {
	my $self = shift;
	my $content = shift;
	my $current_node = $self;

	my $next_direction = $current_node->get_direction_for($content);

	while(defined $current_node->{children}->[$next_direction]) {
		$current_node = $current_node->{children}->[$next_direction];
		$next_direction = $current_node->get_direction_for($content);
	}

	my $new_node = Node->new($content);

	$current_node->{children}->[$next_direction] = $new_node;
	$new_node->set_father($current_node,$next_direction);

	print STDERR "ajout de $content\n";
	$self->create_dot();
	return;
}

sub direction_of_unique_child {
	my $self = shift;
	return NONE unless $self->children_number() == 1;
	if (defined $self->{children}->[LEFT]) {
		return LEFT;
	} else {
		return RIGHT;
	}
}

sub remove {
	my $self = shift;
	my $father = $self->{father};

	my $unique_child_direction = $self->direction_of_unique_child();
	if ($unique_child_direction == NONE) {
		if ($self->children_number() == 0) {
			# no children ! very easy case
			$father->{children}->[get_node_direction($father, $self)] = undef;
		} else {
			#complex case : 2 children : exchange and remove
			my $direction = int rand(2);
			my $last_child = $self->{children}->[$direction]->last_child(1 - $direction);
			$self->{content} = $last_child->{content};
			$last_child->remove();
		}
	} else {
		#easy case : we have only one child
		$father->{children}->[get_node_direction($father, $self)] = $self->{children}->[$unique_child_direction];
		$self->{children}->[$unique_child_direction]->{father} = $father;
	}
	return;
}

# Return the direction of the node given
sub get_node_direction {
	my $self = shift;
	my $child = shift;

	for my $direction (LEFT,RIGHT) {
		next unless defined $self->{children}->[$direction];
		return $direction if $self->{children}->[$direction] == $child;
	}
}

sub children_number {
	my $self = shift;
	return scalar grep { defined $_ } @{$self->{children}};
}

# Set father of the node given
sub set_father {
	my $self = shift;
	my $father = shift;
	my $direction = shift;
	$self->{father} = $father;
	$father->{children}->[$direction] = $self;
}

# Return the last children of the node given
sub last_child {
	my $node = shift;
	my $direction = shift;
	while (defined $node->{children}->[$direction]) {
		$node = $node->{children}->[$direction];
	}
	return $node;
}

# Return the node of the content if he exist
sub find_node {
	my $self = shift;
	my $content = shift;
	my $current_node = $self;

	while(defined $current_node)
	{
		last if $current_node->{content} == $content;
		my $direction = $current_node->get_direction_for($content);
		$current_node = $current_node->{children}->[$direction];
	}

	return $current_node;
}

sub children {
	my $self = shift;
	my @children;
	for my $direction(LEFT, RIGHT) {
		next unless defined $self->{children}->[$direction];
		push @children, $self->{children}->[$direction];
	}
	return @children;
}

# Return the direction for a content
sub get_direction_for {
	my $self = shift;
	my $content = shift;
	return ($content < $self->{content})?LEFT:RIGHT;
}

# Write information of the tree on a file
sub dot_all_content {
	my $self = shift;
	my $fd = shift;

	my $addr = refaddr $self;
	my $content = $self->{content};

	print $fd "$addr [label = $content];\n";

	if (defined $self->{father}) {
		my $addrf = refaddr $self->{father};
		print $fd "$addrf -> $addr\n";
	}
	$_->dot_all_content($fd) for ($self->children());
	return;
}

# Write a file .dot, create the jpg of this and display it
my $directory = '/tmp';
# Incremental id for graphics
my $id_file = 0;
sub create_dot {
	my $self = shift;

	open(my $fd, ">", "$directory/graph$id_file.dot")
		or die "can't open > graph$id_file.dot";

	print $fd "digraph G {\n";
	$self->dot_all_content($fd);
	print $fd "}";

	system "dot -Tjpg -o$directory/graph$id_file.jpg $directory/graph$id_file.dot";
	system "tycat $directory/graph$id_file.jpg";
	$id_file++;
	return;
}

1;
