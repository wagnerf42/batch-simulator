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
	};

	die "bad json_file $self->{json_file}" unless -f $self->{json_file};

	$self->{json} = decode_json(read_file($self->{json_file}));

	# Get information about the jobs
	for my $job (@{$self->{json}->{jobs}}) {
		my $id = $job->{id};

		$self->{jobs}->{$id} = Job->new(
			$job->{id}, # job number
			undef,
			undef,
			undef,
			$job->{res}, # allocated CPUs
			undef,
			undef,
			$job->{res}, # requested CPUs
			$job->{walltime}, # requested time
			undef,
			undef,
			undef
		);
	}

	# Generate the UNIX socket
	$self->{server_socket} = IO::Socket::UNIX->new(
		Type => SOCK_STREAM(),
		Local => '/tmp/bat_socket',
		Listen => 1
	);

	# Wait until we have a connection
	print "waiting for connections\n";
	$self->{socket} = $self->{server_socket}->accept();
	print "connected\n";
	$self->{current_simulator_time} = 0;

	bless $self, $class;
	return $self;
}

=item cpu_number()

Returns the number of cpus in the json file

=cut

sub cpu_number {
	my $self = shift;
	return $self->{json}->{nb_res};
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
	my @jobs_messages = map {$_->job_number().'='.join(',', $_->assigned_processors_ids()->processors_ids())} @{$jobs};
	$message .= join(';', @jobs_messages);

	my $message_size = pack('N', length($message));
	$self->{socket}->send($message_size);
	$self->{socket}->send($message);
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

	my $packed_size = $self->recv(4);
	my $size = unpack('N', $packed_size);
	my $message_content = $self->recv($size);

	my @fields = split('|', $message_content);
	my $check = shift @fields;

	die "error checking head of message : $check" unless $check=~/^0:(\d+(\.\d+)?)$/;
	$self->{current_simulator_time} = $1;

	my @incoming_events;
	for my $field (@fields) {
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

=item _recv(size)

Uses a loop to receive size bytes from the network.

=cut

sub recv {
	my $self = shift;
	my $size = shift;

	my $message_content = '';
	my $tmp;

	while (length($message_content) < $size) {
		$self->{socket}->recv($tmp, $size - length($message_content)) or die 'recv';
		$message_content .= $tmp;
	}

	return $message_content;
}

1;
