package Database;
use strict;
use warnings;

use DBI;
use Data::Dumper qw(Dumper);

use Trace;
use Job;

sub new {
	my ($class) = @_;
	my $self = {
		driver => "SQLite",
		database => "parser.db",
		userid => "",
		password => ""
	};

	$self->{dsn} = "DBI:$self->{driver}:dbname=$self->{database}";
	$self->{dbh} = DBI->connect($self->{dsn}, $self->{userid}, $self->{password}) or die $DBI::errstr;
	
	bless $self, $class;
	return $self;
}

sub prepare_tables {
	my ($self) = @_;

	$self->{dbh}->do("CREATE TABLE IF NOT EXISTS execution (
		id INTEGER NOT NULL,
		trace_file VARCHAR(255),
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

	$self->{dbh}->do("CREATE TABLE IF NOT EXISTS instance (
		id INTEGER NOT NULL,
		trace INTEGER NOT NULL,
		execution INTEGER NOT NULL,
		algorithm VARCHAR(255),
		cmax INT,
		run_time INT,
		PRIMARY KEY (id),
		FOREIGN KEY (execution) REFERENCES execution(id) ON DELETE CASCADE,
		FOREIGN KEY (algorithm) REFERENCES algorithm(id) ON DELETE CASCADE,
		FOREIGN KEY (trace) REFERENCES trace(id) ON DELETE CASCADE
	)");

	$self->{dbh}->do("CREATE TABLE IF NOT EXISTS algorithm (
		id INTEGER NOT NULL,
		name VARCHAR(255) NOT NULL,
		PRIMARY KEY (id)
	)");

	$self->{dbh}->do("CREATE TABLE IF NOT EXISTS trace (
		id INTEGER NOT NULL,
		generation_method VARCHAR(255),
		trace_file VARCHAR(255),
		reset_submit_times INT,
		fix_submit_times INT,
		remove_large_jobs INT,
		PRIMARY KEY (id)
	)");

	$self->{dbh}->do("CREATE TABLE IF NOT EXISTS job (
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
		PRIMARY KEY (id),
		FOREIGN KEY (trace) REFERENCES trace(id) ON DELETE CASCADE
	)");
}

sub add_execution {
	my ($self, $execution) = @_;

	$execution->{add_time} = "SELECT datetime(\"now\")";

	my $key_string = join (',', keys %{$execution});
	my $value_string = join ('\',\'', values %{$execution});
	$self->{dbh}->do("INSERT INTO execution ($key_string) values ('$value_string')");

	my $sth = $self->{dbh}->prepare("SELECT MAX(id) AS id FROM execution");
	$sth->execute();
	my $ref = $sth->fetchrow_hashref();
	my $id = $ref->{id};
	return $id;
}

sub update_execution_run_time {
	my ($self, $execution_id, $run_time) = @_;
	$self->{dbh}->do("UPDATE execution SET run_time = '$run_time' WHERE id = '$execution_id'");
}

sub add_trace {
	my ($self, $trace, $trace_info) = @_;

	my $key_string = join (',', keys %{$trace_info});
	my $value_string = join ('\',\'', values %{$trace_info});
	$self->{dbh}->do("INSERT INTO trace ($key_string) values ('$value_string')");

	my $sth = $self->{dbh}->prepare('SELECT MAX(id) AS id from trace');
	$sth->execute();
	my $ref = $sth->fetchrow_hashref();
	my $trace_id = $ref->{id};

	# Add the jobs
	for my $job (@{$trace->jobs()}) {
		my $key_string = join (',', keys %{$job});
		my $value_string = join ('\',\'', values %{$job});
		$self->{dbh}->do("INSERT INTO job (trace, $key_string) values ('$trace_id', '$value_string')");
	}

	return $trace_id;
}

sub get_trace_ref {
	my ($self, $trace_id) = @_;

	my $sth = $self->{dbh}->prepare("SELECT * FROM traces WHERE id=\'$trace_id\'");
	$sth->execute();
	return $sth->fetchrow_hashref();
}

sub get_job_refs {
	my ($self, $trace_id) = @_;

	my $sth = $self->{dbh}->prepare("SELECT * FROM jobs WHERE trace=\'$trace_id\'");
	$sth->execute();

	my @job_refs;
	while (my $job_ref = $sth->fetchrow_hashref()) {
		push @job_refs, $job_ref;
	}
	return @job_refs;
}

sub add_run {
	my ($self, $trace_id, $algorithm_name, $cmax, $run_time) = @_;

	my $sth = $self->{dbh}->prepare("SELECT id FROM algorithms WHERE name=\'$algorithm_name\'");
	$sth->execute();

	my $algorithm_ref = $sth->fetchrow_hashref();
	die 'unknown algorithm name' unless defined $algorithm_ref;

	my $algorithm_id = $algorithm_ref->{id};

	$self->{dbh}->do("INSERT INTO runs (trace, algorithm, cmax, run_time) VALUES ($trace_id, $algorithm_id, $cmax, $run_time)");
}


1;
