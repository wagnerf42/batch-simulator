package EventQueue;
use strict;
use warnings;
use IO::Socket::UNIX;
use File::Slurp;
use JSON;
use Job;

=head1 NAME

EventQueue - Implementation of the queue using an extern simulator

=head2 METHODS

=over 12

=item new(json_file)

Creates a new EventQueue object.

The objects uses a JSON file to read the information about the jobs and a UNIX
socket to receive events from the external simulator.

=cut

sub new {
	my $class = shift;

	my $self = {
		json_file => shift,
		profile_number => shift
	};

	die "bad json_file $self->{json_file}" unless -f $self->{json_file};

	$self->{json} = json_decode(read_file($self->{json_file}));

	# Get information about the jobs
	for my $job (@{$self->{json}->{jobs}}) {
		my $id = $job->{id};

		$self->{jobs}->{$id} = Job->new(
			$job->{id}, # job number
			undef,
			undef,
			undef,
			$job->{res}, # requested CPUs
			undef,
			undef,
			$job->{res}, # requested CPUs
			$job->{walltime}, # requested time
			undef,
			undef,
			undef
		);
	}

	# Get the number of CPUs and maybe cluster size
	my $profile = $self->{json}->{profiles}->[$self->{profile_number}];
	$self->{processors_number} = $profile->{cpu};
	$self->{cluster_size} = $profile->{cluster_size};

	# Generate the UNIX socket
	$self->{server_socket} = IO::Socket::UNIX->new(
		Type => SOCK_STREAM(),
		Local => '/tmp/bat_socket',
		Listen => 1
	);

	# Wait until we have a connection
	$self->{socket} = $self->{server_socket}->accept();
	$self->{current_simulator_time} = 0;

	bless $self, $class;
	return $self;
}

=item current_time()

Returns the current time in the external simulator.

=cut

sub current_time {
	my $self = shift;
	return $self->{current_simulator_time};
}

=item set_started_jobs(jobs)

Informs the external simulator that jobs have started.

=cut

sub set_started_jobs {
	my $self = shift;
	my $jobs = shift;
	my $message = "0:$self->{current_time}|$self->{current_time}:J:";
	my @jobs_messages = map {$_->job_number().'='.join(',', $_->assigned_processors_ids()->processors_ids()} @{$jobs};
	$message .= join(';', @jobs_messages);
	$message_size = pack('N', length($message));
	send($self->{socket}, $message_size) or die 'send problem';
	send($self->{socket}, $message) or die 'send problem';
	return;
}

=item not_empty()

Returns the connection state of the external simulator.

=cut

sub not_empty {
	my $self = shift;
	return eval{$self->{socket}->connected()};
}

=item retrieve_all()

Retrieves all the available events in the event queue.

=cut

sub retrieve_all {
	my $self = shift;

	my $packed_size = '';

	while (length($packed_size) < 4) {
		my $tmp;
		recv($self->{socket}, $tmp, 4 - length($packed_size)) or die 'receive';
		$packed_size .= $tmp;
	}

	my $size = unpack('N', $packed_size);
	my $message_content = '';

	while (length($message_content) < $size) {
		my $tmp;
		recv($self->{socket}, $tmp, $size - length($message_content)) or die 'receive';
		$message_content .= $tmp;
	}
	my @fields = split('|', $message_content);
	my $check = shift @fields;

	die "error checking head of message : $check" unless $check=~/^0:(\d+(\.\d+)?)$/;
	$self->{current_simulator_time} = $1;

	my @incoming_events;
	for my $field (@field) {
		die "invalid message $field" unless $field=~/^(\d+(\.\d+)?):([SC]):(\d+)/;

		my $timestamp = $1;
		my $type = $2;
		$type = ($type eq 'C') ? 0 : 1;
		my $job_id = $3;

		push @incoming_events, Event->new($type, $timestamp, $self->{jobs}->{$job_id});
	}

	die "no events received" unless @incoming_events;
	return @incoming_events;
}

sub processors_number {
	my $self = shift;
	return $self->{processors_number};
}

sub cluster_size {
	my $self = shift;
	return $self->{cluster_size};
}

1;
