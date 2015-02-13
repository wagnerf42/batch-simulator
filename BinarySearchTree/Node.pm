package BinarySearchTree::Node;

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
	my $key = shift;
	my $current_node = $self;

	my $next_direction = $current_node->get_direction_for($key);

	while(defined $current_node->{children}->[$next_direction]) {
		$current_node = $current_node->{children}->[$next_direction];
		$next_direction = $current_node->get_direction_for($key);
	}

	my $new_node = BinarySearchTree::Node->new($key);

	$current_node->{children}->[$next_direction] = $new_node;
	$new_node->set_father($current_node,$next_direction);

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

#careful, the 'remove' routine can invalidate outside pointers
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

# Return the node of the key if he exist
sub find_node {
	my $self = shift;
	my $key = shift;
	my $current_node = $self;

	while (defined $current_node) {
		last if $current_node->{content} == $key;
		my $direction = $current_node->get_direction_for($key);
		$current_node = $current_node->{children}->[$direction];
	}

	return $current_node;
}

sub nodes_loop {
	my $self = shift;
	my $start_key = shift;
	my $end_key = shift;
	my $routine = shift;

	my $current_node = $self;
	my $continue = 1;

	#we do a depth first exploration
	#which is constrained by the start and end of the range
	#since we do it iteratively we need to handle a stack ourselves
	my @parents; #this is the stack, containing ancestors with right subtree explorations left to do

	while ($continue and (@parents or defined $current_node)) {
		if (defined $current_node) {
			#go left first
			push @parents, $current_node;
			$current_node = ($current_node->{content} > $start_key) ? $current_node->{children}->[LEFT] : undef;
		} else {
			#we returned from exploration of a left child
			$current_node = pop @parents;
			#do content here
			$continue = $routine->($current_node->{content}) if ($current_node->{content} >= $start_key and (not defined $end_key or $current_node->{content} <= $end_key));
			#and continue with right subtree
			$current_node = (not defined $end_key or $current_node->{content} < $end_key) ? $current_node->{children}->[RIGHT] : undef;
		}
	}
	return;
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

# Return the direction for a key
sub get_direction_for {
	my $self = shift;
	my $key = shift;
	return ($key < $self->{content}) ? LEFT : RIGHT;
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

sub save_svg {
	my $self = shift;
	my $filename = shift;
	my $dotfile = $filename;
	$dotfile =~s/svg$/dot/;
	open(my $fd, ">", "$dotfile")
		or die "can't open $dotfile";

	print $fd "digraph G {\n";
	$self->dot_all_content($fd);
	print $fd "}";

	system "dot -Tsvg -o$filename $dotfile";
	close($fd);
	return;
}

1;
