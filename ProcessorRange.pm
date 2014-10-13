package ProcessorRange;

use strict;
use warnings;
use overload '""' => \&stringification;

sub new {
	my $class = shift;
	my $self = {};
	$self->{ranges} = [];
	my $processor_ids = shift;
	die 'not enough processors' unless @{$processor_ids};
	my @processor_ids = sort {$a <=> $b} @{$processor_ids};
	my $previous_id;
	for my $id (@processor_ids) {
		if ((not defined $previous_id) or ($previous_id != $id -1)) {
			push @{$self->{ranges}}, $previous_id if defined $previous_id;
			push @{$self->{ranges}}, $id;
		}
		$previous_id = $id;
	}
	push @{$self->{ranges}}, $previous_id;
	bless $self, $class;
	return $self;
}


sub intersection {
	die 'TODO';
}

sub processors_ids {
	my $self = shift;
	my @ids;
	for my $i (0..(@{$self->{ranges}}-2)/2) {
		my $start = $self->{ranges}->[$i*2];
		my $end = $self->{ranges}->[$i*2+1];
		for my $j ($start..$end) {
			push @ids, $j;
		}
	}
	return @ids;
}

sub stringification {
	my $self = shift;
	my @strings;
	for my $i (0..((@{$self->{ranges}}-2)/2)) {
		my $start = $self->{ranges}->[$i*2];
		my $end = $self->{ranges}->[$i*2+1];
		push @strings, "[$start-$end]";
	}
	return join(' ', @strings);
}

1;
