package Debug;
use strict;
use warnings;
use Filter::Util::Call;
use constant TRUE => 1;
use constant FALSE => 0;
sub import {
	my ($type) = @_;
	my (%context) = (
		Enabled => defined $ENV{DEBUG},
		InTraceBlock => FALSE,
		Filename => (caller)[1],
		LineNo => 0,
		LastBegin => 0,
	);
	filter_add(bless \%context);
}
sub Die {
	my ($self) = shift;
	my ($message) = shift;
	my ($line_no) = shift || $self->{LastBegin};
	die "$message at $self->{Filename} line $line_no.\n"
}
sub filter {
	my ($self) = @_;
	my ($status);
	$status = filter_read();
	++ $self->{LineNo};
# deal with EOF/error first
	if ($status <= 0) {
		$self->Die("DEBUG_BEGIN has no DEBUG_END")
		if $self->{InTraceBlock};
		return $status;
	}
	if ($self->{InTraceBlock}) {
		if (/^\s*##\s*DEBUG_BEGIN/ ) {
			$self->Die("Nested DEBUG_BEGIN", $self->{LineNo})
		} elsif (/^\s*##\s*DEBUG_END/) {
			$self->{InTraceBlock} = FALSE;
		}
# comment out the debug lines when the filter is disabled
		s/^/#/ if ! $self->{Enabled};
	} elsif ( /^\s*##\s*DEBUG_BEGIN/ ) {
		$self->{InTraceBlock} = TRUE;
		$self->{LastBegin} = $self->{LineNo};
	} elsif ( /^\s*##\s*DEBUG_END/ ) {
		$self->Die("DEBUG_END has no DEBUG_BEGIN", $self->{LineNo});
	}
	return $status;
}
1;
