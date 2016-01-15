package Platform;
use strict;
use warnings;

use Log::Log4perl qw(get_logger);
use Data::Dumper;
use List::Util qw(min max sum);
use POSIX;
use XML::Smart;

use Tree;

# Default power, latency and bandwidth values
use constant CLUSTER_POWER => "23.492E9";
use constant CLUSTER_BANDWIDTH => "1.25E9";
use constant CLUSTER_LATENCY => "1.0E-4";
use constant LINK_BANDWIDTH => "1.25E9";
use constant LINK_LATENCY => "1.0E-4";

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

# Platform structure generation code
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

	$self->_score($self->{root}, 0, $requested_cpus);

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

	# Last level
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

sub _score {
	my $self = shift;
	my $tree = shift;
	my $level = shift;
	my $requested_cpus = shift;

	# No needed CPUs
	return 0 unless $requested_cpus;

	# Leaf/CPU
	return 0 if ($level == scalar @{$self->{levels}} - 1);

	# Best combination already saved
	if (defined $tree->content()->{$requested_cpus}) {
		return $tree->content()->{$requested_cpus}->{score};
	}

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

			$score = $self->_score($children[$child_id], $level + 1, $child_requested_cpus);
		}

		if ($score < $best_combination{score}) {
			$best_combination{score} = $score;
			$best_combination{combination} = $combination;
		}
	}

	$tree->content()->{$requested_cpus} = \%best_combination;
	return $best_combination{score};
}

# Platform XML generation code
# This code will be used to generate platform files and host files to be used
# with SMPI initially.
sub build_platform_xml {
	my $self = shift;

	my @platform_parts = @{$self->{levels}};
	my $cluster_size = $platform_parts[$#platform_parts]/$platform_parts[$#platform_parts - 1];
	my $xml = XML::Smart->new();

	$xml->{platform} = {version => 3};

	# Root system
	$xml->{platform}{AS} = {
		id => "AS_Root",
		routing => "Floyd",
	};

	# Tree system
	$xml->{platform}{AS}{AS} = {
		id => "AS_Tree",
		routing => "Floyd",
	};

	# Push the first router
	push @{$xml->{platform}{AS}{AS}{router}}, {id => "R-0-0"};

	# Build levels
	for my $level (1..($#platform_parts - 1)) {
		my $nodes_number = $platform_parts[$level];

		for my $node_number (0..($nodes_number - 1)) {
			push @{$xml->{platform}{AS}{AS}{router}}, {id => "R-$level-$node_number"};

			my $father_node = int $node_number/($platform_parts[$level]/$platform_parts[$level - 1]);
			push @{$xml->{platform}{AS}{AS}{link}}, {
				id => "L-$level-$node_number",
				bandwidth => LINK_BANDWIDTH,
				latency => LINK_LATENCY,
			};

			push @{$xml->{platform}{AS}{AS}{route}}, {
				src => 'R-' . ($level - 1) . "-$father_node",
				dst => "R-$level-$node_number",
				link_ctn => {id => "L-$level-$node_number"},
			};
		}
	}

	# Clusters
	for my $cluster (0..($platform_parts[$#platform_parts - 1] - 1)) {
		push @{$xml->{platform}{AS}{cluster}}, {
			id => "C-$cluster",
			prefix => "",
			suffix => "",
			radical => ($cluster * $cluster_size) . '-' . (($cluster + 1) * $cluster_size - 1),
			power => CLUSTER_POWER,
			bw => CLUSTER_BANDWIDTH,
			lat => CLUSTER_LATENCY,
			router_id => "R-$cluster",
		};

		push @{$xml->{platform}{AS}{link}}, {
			id => "L-$cluster",
			bandwidth => LINK_BANDWIDTH,
			latency => LINK_LATENCY,
		};

		push @{$xml->{platform}{AS}{ASroute}}, {
			src => "C-$cluster",
			gw_src => "R-$cluster",
			dst => "AS_Tree",
			gw_dst => 'R-' . ($#platform_parts - 1) . "-$cluster",
			link_ctn => {id => "L-$cluster"},
		}
	}

	$self->{xml} = $xml;
	return;
}

sub save_platform_xml {
	my $self = shift;
	my $filename = shift;

	open(my $file, '>', $filename);

	print $file "<?xml version=\'1.0\'?>\n" . "<!DOCTYPE platform SYSTEM \"http://simgrid.gforge.inria.fr/simgrid.dtd\">\n" . $self->{xml}->data(noheader => 1, nometagen => 1);

	return;
}

sub save_hostfile {
	my $cpus = shift;
	my $filename = shift;

	open(my $file, '>', $filename);
	print $file join("\n", @{$cpus}) . "\n";

	return;
}

sub generate_all_combinations {
	my $self = shift;
	my $requested_cpus = shift;

	return $self->_combinations($self->{root}, $requested_cpus, 0);
}

sub _score_function_pnorm {
	my $self = shift;
	my $child_requested_cpus = shift;
	my $requested_cpus = shift;
	my $level = shift;

	my $max_depth = scalar @{$self->{levels}} - 1;

	return $child_requested_cpus * ($requested_cpus - $child_requested_cpus) * pow(($max_depth - $level) * 2, $self->{norm});
}

sub _score_function_level {
	my $self = shift;
	my $child_requested_cpus = shift;
	my $requested_cpus = shift;
	my $level = shift;

	return $level;
}


1;
