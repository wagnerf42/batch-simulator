package Tree;
use strict;
use warnings;

# Constructors

sub new {
	my $class = shift;
	my $content = shift;

	my $self = {
		content => $content,
		children => [],
	};

	bless $self, $class;
	return $self;
}

# Public routines

sub add_child {
	my $self = shift;
	my $child = shift;

	push @{$self->{children}}, $child;

	return;

}

# Getters and setters

sub children {
	my $self = shift;
	my $children = shift;

	$self->{children} = $children if defined $children;
	return $self->{children};
}

sub content {
	my $self = shift;
	my $content = shift;

	$self->{content} = $content if defined $content;
	return $self->{content};
}

1;
