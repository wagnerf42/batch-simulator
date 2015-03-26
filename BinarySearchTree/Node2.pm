package BinarySearchTree::Node2;

use Data::Dumper;
use Scalar::Util qw(refaddr);

use parent 'Displayable';
use warnings;
use strict;
use overload '""' => \&stringification;
use constant {
	LEFT => 0,
	RIGHT => 1,
	NONE => 2
};


sub new {
	my $class = shift;
	my $self = {
		key => shift,
		content => shift,
		children => [undef, undef], #left 0, right 1
		father => shift,
		tree => undef
	};

	bless $self, $class;
	return $self unless defined $self->{father}; #root nodes are not counted

	if((ref $self->{key}) eq 'ARRAY') {
		my @remaining_key = @{$self->{key}};
		shift @remaining_key;
		my $remaining_key;
		my $sentinel;
		if (@remaining_key == 1) {
			$sentinel = -1;
			$remaining_key = $remaining_key[0];
		} else {
			$sentinel = [ map {-1} @remaining_key ];
			$remaining_key = \@remaining_key;
		}
		$self->{tree} = BinarySearchTree2::->new($sentinel);
		$self->{tree}->add_content($remaining_key, 0);
		$self->update_count($remaining_key, 1);
	}

	return $self;
}

sub get_tree {
	my $self = shift;
	return $self->{tree};
}

sub get_key {
	my $self = shift;
	return $self->{key};
}

sub update_count {
	my $self = shift;
	my $key = shift;
	my $difference = shift;

	while (defined $self) {
		$self->add_to_count($key, $difference);
		$self = $self->{father};
	}
}

sub add_to_count {
	my $self = shift;
	my $key = shift;
	my $difference = shift;

	return unless defined $self->{tree};
	my $node = $self->{tree}->find_node($key);

	if(defined $node) {
		if(($node->{content} + $difference) != 0) {
			$node->{content} += $difference;
		} else {
			$node->remove();
		}
	} else {
		$self->{tree}->add_content($key, $difference) if ($difference > 0);
	}
	return;
}

sub add {
	my $self = shift;
	my $key = shift;
	my $content = shift;
	my $current_node = $self;

	my $next_direction = $current_node->get_direction_for($key);

	while(defined $current_node->{children}->[$next_direction]) {
		$current_node = $current_node->{children}->[$next_direction];
		$next_direction = $current_node->get_direction_for($key);
	}

	my $new_node = BinarySearchTree::Node2->new($key, $content, $current_node);
	$current_node->{children}->[$next_direction] = $new_node;
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

sub remaining_key {
	my $self = shift;

	if((ref $self->{key}) eq 'ARRAY') {
		my @left_key = @{$self->{key}};
		shift @left_key;
		if(@left_key == 1) {
			return $left_key[0];
		} else {
			return \@left_key;
		}
	} else {
		return $self->{key};
	}
}

sub exchange_content {
	my @nodes = @_;
	my @keys = map { $_->remaining_key() } @nodes;
	($nodes[1]->{content}, $nodes[0]->{content}) = map { $_->{content} } @nodes;
	($nodes[1]->{key}, $nodes[0]->{key}) = map { $_->{key} } @nodes;
	$nodes[0]->update_count($keys[1], 1);
	$nodes[0]->update_count($keys[0], -1);
	$nodes[1]->update_count($keys[0], 1);
	$nodes[1]->update_count($keys[1], -1);
	return;
}

#careful, the 'remove' routine can invalidate outside pointers
sub remove {
	my $self = shift;
	my $father = $self->{father};
	my $remaining_key = $self->remaining_key();

	my $unique_child_direction = $self->direction_of_unique_child();
	if ($unique_child_direction == NONE) {
		if ($self->children_number() == 0) {
			# no children ! very easy case
			$father->update_count($remaining_key, -1);
			$father->{children}->[get_node_direction($father, $self)] = undef;
		} else {
			#complex case : 2 children : exchange and remove
			my $direction = int rand(2);
			my $last_child = $self->{children}->[$direction]->last_child(1 - $direction);
			$self->exchange_content($last_child);
			$last_child->remove();
		}
	} else {
		#easy case : we have only one child
		$father->update_count($remaining_key, -1);
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

	return;
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
		last if $current_node->matches_key($key);
		my $direction = $current_node->get_direction_for($key);
		$current_node = $current_node->{children}->[$direction];
	}

	return $current_node;
}

#return if we have one node on the node tree who match with our range
sub contains_something_between {
	my $self = shift;
	my $start_key = shift;
	my $end_key = shift;
	my $found_someone = 0;

	$self->{tree}->nodes_loop($start_key, $end_key,
		sub {
			$found_someone = 1;
			return 0;
		});
	return $found_someone;
}

sub might_contain_something_between {
	my $self = shift;
	my $start_key = shift;
	my $end_key = shift;

	return 1 unless ref $start_key eq 'ARRAY';

	my @remaining_start_key = @{$start_key};
	my @remaining_end_key = @{$end_key};

	shift @remaining_start_key;
	shift @remaining_end_key;
	$start_key = $remaining_start_key[0] if @remaining_start_key == 1;
	$end_key = $remaining_end_key[0] if @remaining_end_key == 1;

	return $self->contains_something_between($start_key, $end_key);

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
			push @parents, $current_node;

			if ($current_node->matches_range_key($start_key)) {
				my $left_child = $current_node->{children}->[LEFT];
				if (defined $left_child) {
					$current_node = ($left_child->might_contain_something_between($start_key, $end_key)) ? $left_child : undef;
				} else {
					$current_node = undef;
				}
			} else {
				$current_node = undef;
			}

		} else {
			#we returned from exploration of a left child
			$current_node = pop @parents;

			#do content here
			$continue = $routine->($current_node) if ($current_node->matches_range_all_keys($start_key, $end_key));
			#and continue with right subtree

			if ($current_node->matches_range_key(undef, $end_key)) {
				my $right_child = $current_node->{children}->[RIGHT];
				if (defined $right_child) {
					$current_node = ($right_child->might_contain_something_between($start_key, $end_key)) ? $right_child : undef;
				} else {
					$current_node = undef;
				}
			} else {
				$current_node = undef;
			}
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

	if (ref $key eq 'ARRAY') {
		return ($key->[0] < $self->{key}->[0]) ? LEFT : RIGHT;
	} else {
		return ($key < $self->{key}) ? LEFT : RIGHT;
	}
}

sub matches_key {
	my $self = shift;
	my $key = shift;

	if (ref $key eq 'ARRAY' and $self->{key} != -1) {
		my $size = @{$key};
		my $matching = grep { $key->[$_] == $self->{key}->[$_] } (0..($size-1));
		return ($matching == $size);
	} else {
		return ($key == $self->{key});
	}
}

sub matches_range_key {
	my $self = shift;
	my $start_key = shift;
	my $end_key = shift;

	if (ref $self->{key} eq 'ARRAY') {
		if ((not defined $start_key or $self->{key}->[0] >= $start_key->[0]) and (not defined $end_key or $self->{key}->[0] <= $end_key->[0])) {
			return 1;
		}
	} else {
		return ((not defined $start_key or $self->{key} >= $start_key) and (not defined $end_key or $self->{key} <= $end_key));
	}

	return 0;
}

sub matches_range_all_keys {
	my $self = shift;
	my $start_key = shift;
	my $end_key = shift;

	if (ref $self->{key} eq 'ARRAY') {
		my $size = @{$self->{key}};
		for my $i (0 .. $size-1) {
			if ((defined $start_key && $self->{key}->[$i] < $start_key->[$i]) || (defined $end_key && $self->{key}->[$i] > $end_key->[$i])) {
				return 0;
			}
		}
		return 1;
	} else {
		return ((not defined $start_key or $self->{key} >= $start_key) and (not defined $end_key or $self->{key} <= $end_key));
	}
	return 0;
}

# Write information of the tree on a file
sub dot_all_content {
	my $self = shift;
	my $fd = shift;

	my $addr = refaddr $self;
	my $key = $self->{key};
	$key = join(',', @{$key}) if ref($key) eq 'ARRAY';
	my $content = $self->{content};

	print $fd "$addr [label = \"$key:$content\"];\n";

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

sub stringification {
	my $self = shift;
	if (ref $self->{key} eq 'ARRAY') {
		return "@{$self->{key}}";
	} else {
		return "$self->{key}";
	}
}

1;
