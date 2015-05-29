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

	my $self = {
		levels => $levels,
		available_cpus => $available_cpus,
	};

	bless $self, $class;
	return $self;
}

# Public routines

sub build_structure {
	my $self = shift;

	$self->{root} = $self->_build(0, 0);
	return;
}

sub choose_cpus {
	my $self = shift;
	my $requested_cpus = shift;

	my $logger = get_logger('Platform::choose_cpus');

	my $min_distance = $self->_min_distance($self->{root}, 0, $requested_cpus);
	return $self->_choose_cpus($self->{root}, $requested_cpus);
}

# Internal routines

sub _build {
	my $self = shift;
	my $level = shift;
	my $node = shift;

	my $logger = get_logger('Platform::_build');

	#TODO Change this so that setting up the available CPUs is a separate
	#step. The idea is to only do it in the end. Then I can use the tree
	#structure to do it in log time.
	if ($level == scalar @{$self->{levels}} - 1) {
		$logger->debug("last level, returning");
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

	my $logger = get_logger('Platform::_combinations');
	#$logger->debug("running for requested cpus $requested_cpus node $node");

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

	my $logger = get_logger('Platform::_choose_cpus');

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
			$score += $child_requested_cpus * ($requested_cpus - $child_requested_cpus) * ($max_depth - $level) * 2;
		}

		if ($score < $best_combination{score}) {
			$best_combination{score} = $score;
			$best_combination{combination} = $combination;
		}
	}

	$tree->content()->{$requested_cpus} = \%best_combination;

	$logger->debug("returning score $best_combination{score} for combination $best_combination{combination}");
	return $best_combination{score};
}

sub _choose_cpus {
	my $self = shift;
	my $tree = shift;
	my $requested_cpus = shift;

	my $logger = get_logger('Platform::_choose_cpus');

	# No requested cpus
	return unless $requested_cpus;

	my @children = @{$tree->children()};

	# Leaf node/CPU
	return $tree->content()->{id} unless (scalar @children);

	my $best_combination = $tree->content()->{$requested_cpus};
	my @combination_parts = split('-', $best_combination->{combination});

	return map {$self->_choose_cpus($_, shift @combination_parts)} (@children);
}

# Getters and setters

1;
