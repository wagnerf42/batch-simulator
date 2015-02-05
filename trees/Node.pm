package Node;

use Data::Dumper;

use warnings;
use strict;
use constant {
	LEFT => 0,
	RIGHT => 1,
	NONE => 2
};

# Incremental id for graphics
my $id_file = 0;

sub new {
	my $class = shift;
	my $self = {
		content => shift,
		children => [undef,undef], #left 0, right 1
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
	
#	my $current_parent = $location_on_tree;
#	
#	#TODO
#	while($current_parent->{priority} > $random_priority)
#	{
#		$current_parent = ($content < $current_parent->{content} ? rotate_right($current_parent) : rotate_left($current_parent));
#	}
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
	my $node = shift;
	my $father = $node->{father};

	my $unique_child_direction = $node->direction_of_unique_child();
	if ($unique_child_direction == NONE) {

		if ($self->children_number() == 0) {
			# no children ! very easy case
			$father->{children}->[get_node_direction($father,$node)] = undef;
		} else {
			#complex case : 2 children : exchange and remove
			my $direction = int rand(2);
			my $last_child = $self->last_child($node->{children}->[$direction], 1 - $direction);
			$node->{content} = $last_child->{content};
			$self->remove($last_child);
		}

	} else {
		#easy case : we have only one child
		$father->{children}->[get_node_direction($father,$node)] = $node->{children}->[$unique_child_direction];
		$node->{children}->[$unique_child_direction]->{father} = $father;
	}
	return;
}

sub rotate {
	# For left rotate of D
	#	      A 		  	  A
	#		 /			     /
	#	 	B 			  	D
	#	   / \		 => 	 \
	#	  C   D 		      B
	#		   \			 / \
	#			E			C   E
	#
	my $father = shift;
	my $direction = shift;
	my $other_direction = 1 - $direction;
	my $child = $father->{children}->[$direction];
	my $grandfather = $father->{father};
	my $b = $child->{children}->[$direction];
	my $grand_father_direction = $grandfather->get_node_direction($father);

	$father->set_father($child, $direction);
	$b->set_father($father, $other_direction);
	$child->set_father($grandfather, $grand_father_direction);
	return;
}

# Return the direction of the node given
sub get_node_direction {
	my $self = shift;
	my $child = shift;

	for my $direction (LEFT,RIGHT) {
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

# Return children of the node given
sub children {
	my $self = shift;
	return $self->{children};
}

# Return the last children of the node given
sub last_child {
	my ($self, $node, $direction) = @_;
	while (defined $node->{children}->[$direction]) {
		$node = $node->{children}->[$direction];
	}
	return $node;
}

# Return the father of the node given
sub father {
	my $self = shift;
	return $self->{father};
}

# Return the node of the content if he exist
sub find_node {
	my $self = shift;
	my $content = shift;
	my $current_node = $self;

	while(defined $current_node)
	{
		last if $current_node->{content} == $content;
		my $direction = ($current_node->{content} < $content ? RIGHT : LEFT);
		$current_node = $current_node->{children}->[$direction];
	}
	
	return $current_node;
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
	my $node = shift;
	my $fi = shift;

	my $addr =  $node;
	my $content = $node->{content};

	print $fi "$content [label = $content];\n";

	if(defined $node->{father}) {
		my $addrf = \($node->{father});
		print $fi "$node->{father}->{content} -> $content\n";
	}
	if(defined $node->{children}->[LEFT]) {
		$self->dot_all_content($node->{children}->[LEFT],$fi);
	}
	if(defined $node->{children}->[RIGHT]) {
		$self->dot_all_content($node->{children}->[RIGHT],$fi);
	}
}

# Write a file .dot, create the jpg of this and display it
sub create_dot {
	my $self = shift;

	open(my $fi,">","graph/graph$id_file.dot")
		or die "can't open > graph$id_file.dot";

	print $fi "digraph G {\n";
	$self->dot_all_content($self,$fi);
	print $fi "}";

	system "dot -Tjpg -ograph/graph$id_file.jpg graph/graph$id_file.dot";
	system "tycat graph/graph$id_file.jpg";
	$id_file++;
}

1;
