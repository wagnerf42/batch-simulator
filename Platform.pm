package Platform;
use strict;
use warnings;

use Log::Log4perl qw(get_logger);
use Data::Dumper;
use List::Util qw(min max sum);
use POSIX;

use Tree;

# Constructors

sub new {
	my $class = shift;
	my $levels = shift;
	my $available_cpus = shift;
	my $norm = shift;

	my $self = {
		levels => $levels,
		available_cpus => $available_cpus,
		norm => $norm,
	};

	bless $self, $class;
	return $self;
}

# Public routines

# Internal routines

# Getters and setters

# Version 1
# This is the exact version of the algorithm. It builds a list of all the
# possible combination of CPUs and checks to see which one is the best. Takes a
# long time in normal sized platforms.

sub build_structure {
	my $self = shift;

	$self->{root} = $self->_build(0, 0);
	return;
}

sub choose_cpus {
	my $self = shift;
	my $requested_cpus = shift;

	my $min_distance = $self->_min_distance($self->{root}, 0, $requested_cpus);
	return $self->_choose_cpus($self->{root}, $requested_cpus);
}

sub _choose_cpus {
	my $self = shift;
	my $tree = shift;
	my $requested_cpus = shift;

	# No requested cpus
	return unless $requested_cpus;

	my @children = @{$tree->children()};

	# Leaf node/CPU
	return $tree->content()->{id} if (defined $tree->content()->{id});

	my $best_combination = $tree->content()->{$requested_cpus};
	my @combination_parts = split('-', $best_combination->{combination});

	return map {$self->_choose_cpus($_, shift @combination_parts)} (@children);
}

sub _build {
	my $self = shift;
	my $level = shift;
	my $node = shift;

	#TODO Change this so that setting up the available CPUs is a separate
	#step. The idea is to only do it in the end. Then I can use the tree
	#structure to do it in log time.
	if ($level == scalar @{$self->{levels}} - 1) {
		my $cpu_is_available = grep {$_ == $node} (@{$self->{available_cpus}});
		my $tree_content = {total_size => $cpu_is_available, id => $node};
		return Tree->new($tree_content);
	}

	my $next_level_nodes = $self->{levels}->[$level + 1]/$self->{levels}->[$level];
	my @next_level_nodes_ids = map {$next_level_nodes * $node + $_} (0..($next_level_nodes - 1));
	my @children = map {$self->_build($level + 1, $_)} (@next_level_nodes_ids);

	my $total_size = 0;
	$total_size += $_->content()->{total_size} for (@children);

	my $tree_content = {total_size => $total_size};
	my $tree = Tree->new($tree_content);
	$tree->children(\@children);
	return $tree;
}

sub _combinations {
	my $self = shift;
	my $tree = shift;
	my $requested_cpus = shift;
	my $node = shift;

	my @children = @{$tree->children()};
	my $last_child = $#children;

	# Last node
	return $requested_cpus if ($node == $last_child);

	my @remaining_children = @children[($node + 1)..$last_child];
	my $remaining_size = sum (map {$_->content()->{total_size}} @children[($node + 1)..$last_child]);
	
	my $minimum_cpus = max(0, $requested_cpus - $remaining_size);
	my $maximum_cpus = min($children[$node]->content()->{total_size}, $requested_cpus);

	my @combinations;

	for my $cpus_number ($minimum_cpus..$maximum_cpus) {
		my @children_combinations = $self->_combinations($tree, $requested_cpus - $cpus_number, $node + 1);

		for my $children_combination (@children_combinations) {
			push @combinations, join('-', $cpus_number, $children_combination);
		}
	}

	return @combinations;
}

sub _min_distance {
	my $self = shift;
	my $tree = shift;
	my $level = shift;
	my $requested_cpus = shift;

	# No needed CPUs
	return 0 unless $requested_cpus;

	# Leaf/CPU
	return 0 if ($level == scalar @{$self->{levels}} - 1);

	# Best combination already saved
	return $tree->content()->{$requested_cpus}->{score} if (defined $tree->content()->{$requested_cpus});

	my @children = @{$tree->children()};
	my $last_child = $#children;
	my @combinations = $self->_combinations($tree, $requested_cpus, 0);
	my $max_depth = scalar @{$self->{levels}} - 1;
	my %best_combination = (score => LONG_MAX, combination => '');

	for my $combination (@combinations) {
		my @combination_parts = split('-', $combination);
		my $score = 0;

		for my $child_id (0..$last_child) {
			my $child_size = $children[$child_id]->content()->{total_size};
			my $child_requested_cpus = $combination_parts[$child_id];

			$score += $self->_min_distance($children[$child_id], $level + 1, $child_requested_cpus);
			$score += $child_requested_cpus * ($requested_cpus - $child_requested_cpus) * pow(($max_depth - $level) * 2, $self->{norm});
		}

		if ($score < $best_combination{score}) {
			$best_combination{score} = $score;
			$best_combination{combination} = $combination;
		}
	}

	$tree->content()->{$requested_cpus} = \%best_combination;
	return $best_combination{score};
}

# Version 2
# This version is not exact. The idea is to give a good answer even if it's not
# the best.  What it does is sort the children of the top of the tree by size
# and pick the largest branches.  This helps decrease the fragmentation of the
# solution and gives a good solution.

sub build_structure2 {
	my $self = shift;

	$self->{root} = $self->_build2(0, 0);
	return;
}

sub choose_cpus2 {
	my $self = shift;
	my $requested_cpus = shift;

	return $self->_choose_cpus2($self->{root}, $requested_cpus);
}

sub _choose_cpus2 {
	my $self = shift;
	my $tree = shift;
	my $requested_cpus = shift;

	#print STDERR "new call $requested_cpus\n";

	# Leaf node/CPU
	return $tree->content()->{id} if (defined $tree->content()->{id});

	my @children = sort {$b->content()->{total_size} <=> $a->content()->{total_size}} (@{$tree->children()});
	my $remaining_cpus = $requested_cpus;
	my @selected_cpus;

	#print STDERR 'children sizes ' . join(' ', map {$_->content()->{total_size}} (@children)) . "\n";

	for my $child (@children) {
		die 'reached child with size 0' unless ($child->content()->{total_size});

		my @child_cpus = $self->_choose_cpus2($child, min($child->content()->{total_size}, $remaining_cpus));
		push @selected_cpus, @child_cpus;
		$remaining_cpus -= scalar @child_cpus;

		#print STDERR "child: @child_cpus selected: @selected_cpus\n";
		#print STDERR "remaining: $remaining_cpus\n";

		return @selected_cpus if (scalar @selected_cpus == $requested_cpus);
	}

	die 'should not reach this point';
}

sub _build2 {
	my $self = shift;
	my $level = shift;
	my $node = shift;

	if ($level == scalar @{$self->{levels}} - 1) {
		my $cpu_is_available = grep {$_ == $node} (@{$self->{available_cpus}});
		my $content = {total_size => $cpu_is_available, id => $node, distance => 0};
		return Tree->new($content);
	}

	my $next_level_nodes = $self->{levels}->[$level + 1]/$self->{levels}->[$level];
	my @next_level_nodes_ids = map {$next_level_nodes * $node + $_} (0..($next_level_nodes - 1));
	my $max_depth = scalar @{$self->{levels}} - 1;
	my @children = map {$self->_build2($level + 1, $_)} (@next_level_nodes_ids);

	my $total_size = 0;
	my $total_distance = 0;

	for my $child (@children) {
		my $content = $child->content();
		$total_size += $content->{total_size};
		$total_distance += $content->{distance} + $content->{total_size} * ($total_size - $content->{total_size}) * ($max_depth - $level) * 2;
	}


	my $content = {total_size => $total_size, distance => $total_distance};
	my $tree = Tree->new($content);
	$tree->children(\@children);
	return $tree;
}

1;
