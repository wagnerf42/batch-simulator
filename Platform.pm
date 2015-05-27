package Platform;
use strict;
use warnings;

use Log::Log4perl qw(get_logger);

use Tree;

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

sub build_structure {
	my $self = shift;

	$self->{structure} = $self->_build(0, 0);
	return;
}

sub _build {
	my $self = shift;
	my $level = shift;
	my $node = shift;

	my $logger = get_logger('Platform::_build');

	if ($level == scalar @{$self->{levels}} - 2) {
		$logger->debug("last level, returning");
		return Tree->new(1);
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

sub structure {
	my $self = shift;
	return $self->{structure};
}

1;
