package Database;
use strict;
use warnings;

use DBI;
use Data::Dumper qw(Dumper);

use Trace;
use Job;

#TODO: switch to new code

sub new {
	my ($class) = @_;
	my $self = {
		driver => "SQLite",
		database => "parser.db",
		userid => "",
		password => "",
	};

	$self->{dsn} = "DBI:$self->{driver}:dbname=$self->{database}";
	$self->{dbh} = DBI->connect($self->{dsn}, $self->{userid}, $self->{password}) or die;
	
	bless $self, $class;
	return $self;
}

sub prepare_tables {
	my ($self) = @_;

	$self->{dbh}->do("CREATE TABLE IF NOT EXISTS executions (
		id INTEGER NOT NULL,
		trace_file VARCHAR(255),
		script_name VARCHAR(255),
		jobs_number INT,
		executions_number INT,
		cpus_number INT,
		threads_number INT,
		cluster_size INT,
		git_revision VARCHAR(255),
		git_tree_dirty INT,
		run_time INT,
		comments VARCHAR(255),
		add_time DATETIME,
		PRIMARY KEY (id)
	)");

	$self->{dbh}->do("CREATE TABLE IF NOT EXISTS instances (
		id INTEGER NOT NULL,
		trace INTEGER NOT NULL,
		execution INTEGER NOT NULL,
		algorithm VARCHAR(255),
		cmax INT,
		run_time INT,
		results BLOB,
		PRIMARY KEY (id),
		FOREIGN KEY (execution) REFERENCES executions(id) ON DELETE CASCADE,
		FOREIGN KEY (trace) REFERENCES traces(id) ON DELETE CASCADE
	)");

	$self->{dbh}->do("CREATE TABLE IF NOT EXISTS traces (
		id INTEGER NOT NULL,
		generation_method VARCHAR(255),
		trace_file VARCHAR(255),
		reset_submit_times INT,
		fix_submit_times INT,
		remove_large_jobs INT,
		PRIMARY KEY (id)
	)");

	$self->{dbh}->do("CREATE TABLE IF NOT EXISTS jobs (
		id INTEGER NOT NULL,
		trace INTEGER NOT NULL,
		job_number INT,
		submit_time INT,
		wait_time INT,
		new_wait_time INT,
		run_time INT,
		allocated_cpus INT,
		avg_cpu_time INT,
		used_mem INT,
		requested_cpus INT,
		requested_time INT,
		requested_mem INT,
		status INT,
		uid INTEGER,
		gid INTEGER,
		exec_number INT,
		queue_number INT,
		partition_number INT,
		prec_job_number INT,
		think_time_prec_job INT,
		assigned_processors VARCHAR(255),
		starting_time INT,
		schedule_time INT,
		PRIMARY KEY (id),
		FOREIGN KEY (trace) REFERENCES traces(id) ON DELETE CASCADE
	)");
	return;
}

sub get_max_id {
	my ($self, $table_name) = @_;
	my $sth = $self->{dbh}->prepare("SELECT MAX(id) AS id FROM $table_name");
	$sth->execute();

	my $ref = $sth->fetchrow_hashref();
	my $id = $ref->{id};
	return $id;
}

sub get_keysvalues {
	my ($self, $hash) = @_;
	my $key_string = join (", ", keys %{$hash});
	my $value_string = join ("', '", values %{$hash});
	return ($key_string, $value_string);
}

sub add_execution {
	my ($self, $execution) = @_;
	my ($key_string, $value_string) = $self->get_keysvalues($execution);
	my $add_time_string = "(SELECT datetime(" . time() . ", 'unixepoch', 'localtime'))";

	my $statement = "INSERT INTO executions (add_time, $key_string) VALUES ($add_time_string, '$value_string')";
	$self->{dbh}->do($statement);
	return $self->get_max_id("executions");
}

sub add_instance {
	my ($self, $execution_id, $trace_id, $results, $instance_info) = @_;
	my ($key_string, $value_string) = $self->get_keysvalues($instance_info);

	my $statement = "INSERT INTO instances (execution, trace, results, $key_string) VALUES ($execution_id, '$trace_id', '" . join(' ', @{$results}) . "', '$value_string')";
	$self->{dbh}->do($statement);
	return $self->get_max_id("instances");
}

sub update_execution_run_time {
	my ($self, $execution_id, $run_time) = @_;
	$self->{dbh}->do("UPDATE executions SET run_time = '$run_time' WHERE id = '$execution_id'");
	return;
}

sub add_trace {
	my ($self, $trace, $trace_info, $add_jobs) = @_;
	my ($key_string, $value_string) = $self->get_keysvalues($trace_info);

	my $statement = "INSERT INTO traces ($key_string) VALUES ('$value_string')";
	$self->{dbh}->do($statement);
	my $trace_id = $self->get_max_id("traces");

	if ($add_jobs) {
		for my $job (@{$trace->jobs()}) {
			# Have to delete some extra keys
			delete $job->{assigned_processors_ids};
			delete $job->{schedule_cmax};

			my ($key_string, $value_string) = $self->get_keysvalues($job);

			my $statement = "INSERT INTO jobs (trace, $key_string) VALUES ('$trace_id', '$value_string')";
			$self->{dbh}->do($statement);
		}
	}

	return $trace_id;
}

sub get_trace_ref {
	my ($self, $trace_id) = @_;

	my $sth = $self->{dbh}->prepare("SELECT * FROM traces WHERE id='$trace_id'");
	$sth->execute();
	return $sth->fetchrow_hashref();
}

sub get_jobs_refs {
	my ($self, $trace_id) = @_;

	my $sth = $self->{dbh}->prepare("SELECT * FROM jobs WHERE trace=\'$trace_id\'");
	$sth->execute();

	my @job_refs;
	while (my $job_ref = $sth->fetchrow_hashref()) {
		push @job_refs, $job_ref;
	}
	return @job_refs;
}

1;
