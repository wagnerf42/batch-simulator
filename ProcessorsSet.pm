package ProcessorsSet;

use strict;
use warnings;

sub new {
	my $class = shift;
	my $self = sort_processors(@_);
	bless $self, $class;
	return $self;
}

sub sort_processors {
	my %processors;
	$processors{$_} = $_ for @_;
	my @sorted_ids = sort {$a <=> $b} (keys %processors);
	my $sorted_processors = [];
	push @{$sorted_processors}, $processors{$_} for @sorted_ids;
	return $sorted_processors;
}

sub contains_at_least {
	my $self = shift;
	my $n = shift;
	return (@{$self} >= $n);
}

#reduce number of processors to given value
#tries to stay contiguous if possible
sub reduce_to {
	my $self = shift;
	my $number = shift;

	#try each position and see if we can get a contiguous block
	for my $start_index (0..$#{$self}) {
		my $ok = 1;
		my $start_id = $self->[$start_index]->id();
		for my $num (1..($number-1)) {
			my $index = ($start_index + $num) % @{$self};
			my $id = $self->[$index]->id();
			my $expected_id = ($start_id + $num) % @{$self};
			if ($id != $expected_id) {
				$ok = 0;
				last;
			}
		}
		if ($ok) {
			$self->keep_from($start_index, $number);
			return;
		}
	}
	$self->keep_from(0, $number);
}

sub reduce_to_contiguous {
	my $self = shift;
	my $number = shift;

	#try each position and see if we can get a contiguous block
	for my $start_index (0..$#{$self}) {
		my $ok = 1;
		my $start_id = $self->[$start_index]->id();
		for my $num (1..($number-1)) {
			my $index = ($start_index + $num) % @{$self};
			my $id = $self->[$index]->id();
			my $expected_id = ($start_id + $num) % @{$self};
			if ($id != $expected_id) {
				$ok = 0;
				last;
			}
		}
		if ($ok) {
			$self->keep_from($start_index, $number);
			return;
		}
	}

	# In this case it was not possible, return an empty answer
	@{$self} = ();
}

sub keep_from {
	my $self = shift;
	my $index = shift;
	my $n = shift;
	my @kept_processors;
	for my $i ($index..($index+$n-1)) {
		my $real_index = $i % @{$self};
		push @kept_processors, $self->[$real_index];
	}
	@{$self} = @kept_processors;
}

sub processors {
	my $self = shift;
	return @{$self};
}

1;
