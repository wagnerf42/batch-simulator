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

	return $self->_choose_cpus($self->{root}, 0, $requested_cpus);
}

# Internal routines

sub _build {
	my $self = shift;
	my $level = shift;
	my $node = shift;

	my $logger = get_logger('Platform::_build');

	if ($level == scalar @{$self->{levels}} - 1) {
		$logger->debug("last level, returning");
		my $cpu_is_available = grep {$_ == $node} (@{$self->{available_cpus}});
		return Tree->new($cpu_is_available);
	}

	$logger->debug("running for level $level node $node");

	my $next_level_nodes = $self->{levels}->[$level + 1]/$self->{levels}->[$level];
	$logger->debug("next level nodes: $next_level_nodes");

	my @next_level_nodes_ids = map {$next_level_nodes * $node + $_} (0..($next_level_nodes - 1));
	$logger->debug("next level ids: @next_level_nodes_ids");

	my @children = map {$self->_build($level + 1, $_)} (@next_level_nodes_ids); 

	$logger->debug("continuing level $level node $node");

	my $total_size = 0;
	$total_size += $_->content() for (@children);
	$logger->debug("total size $total_size");

	my $tree = Tree->new($total_size);
	$tree->children(\@children);
	return $tree;
}

sub _combinations {
	my $self = shift;
	my $tree = shift;
	my $requested_cpus = shift;
	my $node = shift;

	my $logger = get_logger('Platform::_combinations');
	$logger->debug("running for requested cpus $requested_cpus node $node");

	my @children = @{$tree->children()};
	my $last_child = $#children;
	$logger->debug("last child $last_child");

	# Last node
	return $requested_cpus if ($node == $last_child); 

	my @remaining_children = @children[($node + 1)..$last_child];
	my $remaining_size = sum (map {$_->content()} @children[($node + 1)..$last_child]);
	
	my $minimum_cpus = max(0, $requested_cpus - $remaining_size);
	my $maximum_cpus = min($children[$node]->content(), $requested_cpus);
	$logger->debug("min $minimum_cpus max $maximum_cpus");

	my @combinations;

	for my $cpus_number ($minimum_cpus..$maximum_cpus) {
		my @children_combinations = $self->_combinations($tree, $requested_cpus - $cpus_number, $node + 1);

		for my $children_combination (@children_combinations) {
			push @combinations, join('-', $cpus_number, $children_combination);
		}
	}

	return @combinations;
}

sub _choose_cpus {
	my $self = shift;
	my $tree = shift;
	my $level = shift;
	my $requested_cpus = shift;

	my $logger = get_logger('Platform::_choose_cpus');

	# No needed CPUs
	return 0 unless $requested_cpus;

	# Leaf/CPU
	return 0 if ($level == scalar @{$self->{levels}} - 1);

	my @children = @{$tree->children()};
	my $last_child = $#children;
	my @combinations = $self->_combinations($tree, $requested_cpus, 0);
	my $max_depth = scalar @{$self->{levels}} - 1;

	my $best_combination;
	my $best_combination_score = LONG_MAX;

	for my $combination (@combinations) {
		my @combination_parts = split('-', $combination);
		my $score = 0;

		for my $child_id (0..$last_child) {
			my $child_size = $children[$child_id]->content();
			my $child_requested_cpus = $combination_parts[$child_id];

			$score += $self->_choose_cpus($children[$child_id], $level + 1, $child_requested_cpus);
			$score += $child_requested_cpus * ($requested_cpus - $child_requested_cpus) * ($max_depth - $level) * 2;
		}

		if ($score < $best_combination_score) {
			$best_combination_score = $score;
			$best_combination = $combination;
		}
	}
	
	$logger->debug("returning score $best_combination_score for combination $best_combination");
	return $best_combination_score;
}

# Getters and setters

1;
