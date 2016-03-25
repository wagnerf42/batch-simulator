package EventQueue;

use strict;
use warnings;

use IO::Socket::UNIX;
use File::Slurp;
use Data::Dumper;
use JSON;

use Job;

use Debug;

# Creates a new EventQueue object.

# The objects uses a JSON file to read the information about the jobs and a
# UNIX socket to receive events from the external simulator.
sub new {
	my $class = shift;

	my $self = {
		socket_file => shift,
		json_file => shift,
	};

	die "bad json_file $self->{json_file}" unless -f $self->{json_file};
	my $json_data = read_file($self->{json_file});
	$self->{json} = decode_json($json_data);

	# Get information about the jobs
	for my $job (@{$self->{json}->{jobs}}) {
		my $id = $job->{id};

		$self->{jobs}->{$id} = Job->new(
			$job->{id}, # job number
			undef,
			$job->{original_wait_time},
			$job->{walltime}, #it is a lie but temporary
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

	# Generate the UNIX socketa
	do {
		sleep(1);

		##DEBUG_BEGIN
		print STDERR "looking for socket $self->{socket_file}\n";
		##DEBUG_END

		$self->{socket} = IO::Socket::UNIX->new(
			Type => SOCK_STREAM(),
			Peer => $self->{socket_file},
		);
	} until (defined $self->{socket});

	$self->{current_simulator_time} = 0;

	bless $self, $class;
	return $self;
}

# Returns the number of cpus in the json file
sub cpu_number {
	my $self = shift;
	return $self->{json}->{nb_res};
}

# Returns the current time in the external simulator.
sub current_time {
	my $self = shift;
	return $self->{current_simulator_time};
}

# Informs the external simulator that jobs have started.
sub set_started_jobs {
	my $self = shift;
	my $jobs = shift;

	my $message = "0:$self->{current_simulator_time}|$self->{current_simulator_time}:";

	if (@{$jobs}) {
		my @jobs_messages = map {$_->job_number() . '=' . join(',', $_->assigned_processors()->processors_ids())} @{$jobs};

		$message .= 'J:' . join(';', @jobs_messages);
	} else {
		$message .= 'N';
	}

	my $message_size = pack('L', length($message));

	##DEBUG_BEGIN
	print STDERR "sending message (" . length($message) . " bytes): $message\n";
	##DEBUG_END

	$self->{socket}->send($message_size);
	$self->{socket}->send($message);

	return;
}

# Retrieves all the available events in the event queue.
sub retrieve_all {
	my $self = shift;

	my $packed_size = $self->recv(4);
	return unless length($packed_size) == 4;
	my $size = unpack('L', $packed_size);

	my $message_content = $self->recv($size);
	return unless length($message_content) == $size;

	my @fields = split('\|', $message_content);
	my $check = shift @fields;

	##DEBUG_BEGIN
	print STDERR "received message $message_content\n";
	##DEBUG_END

	die "error checking head of message: $check" unless $check=~/^(\d):(\d+(\.\d+)?)$/;
	$self->{current_simulator_time} = $2;

	my @incoming_events;
	for my $field (@fields) {
		die "invalid message $field" unless ($field =~ /^(\d+(\.\d+)?):([SC]):(\d+)/);

		my $timestamp = $1;
		my $type = $3;
		$type = ($type eq 'C') ? 0 : 1;
		my $job_id = $4;

		die "no job for id $job_id in $self->{json}" unless defined $self->{jobs}->{$job_id};
		push @incoming_events, Event->new($type, $timestamp, $self->{jobs}->{$job_id});
	}

	die "no events received" unless @incoming_events;
	return @incoming_events;
}

# Uses a loop to receive size bytes from the network.

# With the current implementation, the routine starts writing on an empty
# string. The loop is used to continuously receive data from the socket. If
# somehow the socket is closed and stops transmitting data, the routine stops
# and returns whatever has been read up to that point.

# The return value is an string with the received message. It can be empty if
# nothing was read but the socket is still working.
sub recv {
	my $self = shift;
	my $size = shift;
	my $message_content = '';
	my $tmp;

	while (length($message_content) < $size) {
		my $result = $self->{socket}->sysread($tmp, $size - length($message_content));
		die 'error receiving message' unless defined $result;
		last unless $result > 0;
		$message_content .= $tmp;
	}

	return $message_content;
}

1;
