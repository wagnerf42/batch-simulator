package EventLine;

use strict;
use warnings;
use Carp;
use POSIX;

#this class is used internally in ProcessorRange for set operations
#it contains an integrated iterator on all event points of the ProcessorRange

sub new {
	my $class = shift;
	my $self = {};
	$self->{events} = shift;
	$self->{inverted} = shift;
	$self->{next_event_index} = 0;
	bless $self, $class;
	return $self;
}

sub get_last_limit {
	my $self = shift;
	return $self->{events}->[$#{$self->{events}}];
}

sub is_not_completed {
	my $self = shift;
	if($self->{inverted}) {
		#we need a max processor index in order to compute the complement
		my $limit = shift;
		return not(($self->{next_event_index} == $#{$self->{events}}) and ($self->{events}->[$self->{next_event_index}] >= $limit));
	} else {
		return ($self->{next_event_index} <= $#{$self->{events}});
	}
}

sub advance {
	my $self = shift;
	$self->{next_event_index}++;
}

#returns 0 for start of range and 1 for end
sub get_event_type {
	my $self = shift;
	confess "we are after limit" if $self->{next_event_index} > $#{$self->{events}};
	return (($self->{next_event_index} + $self->{inverted})%2);
}

sub get_x {
	my $self = shift;
	return LONG_MAX if $self->{next_event_index} > $#{$self->{events}};
	if ($self->{inverted}) {
		if ($self->get_event_type()) {
			#end : we end one unit before indicated time
			return $self->{events}->[$self->{next_event_index}] - 1;
		} else {
			#start : we start in fact one unit after stored position
			return $self->{events}->[$self->{next_event_index}] + 1;
		}
	} else {
		return $self->{events}->[$self->{next_event_index}];
	}
}

1;
