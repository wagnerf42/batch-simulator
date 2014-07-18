package Database;
use strict;
use warnings;

use DBI;

use Trace;
use Job;

sub new {
	my $class = shift;
	my $self = {
		driver => "mysql",
		database => "parser",
		userid => "parser",
		password => "parser"
	};

	$self->{dsn} = "DBI:$self->{driver}:database=$self->{database}";
	$self->{dbh} = DBI->connect($self->{dsn}, $self->{userid}, $self->{password}) or die $DBI::errstr;
	
	bless $self, $class;
	return $self;
}

sub prepare_tables {
	my $self = shift;

	$self->{dbh}->do("CREATE TABLE executions (
		id INT NOT NULL,
		fcfs_cmax INT,
		fcfs_is_contiguous BOOL,
		fcfs_run_time INT,
		backfilling_cmax INT,
		backfilling_is_contiguous BOOL,
		backfilling_run_time INT,
		backfilled_jobs INT,
		status INT,
		PRIMARY KEY (id)
	)");

	$self->{dbh}->do("CREATE TABLE traces (
		id INT NOT NULL,
		execution INT NOT NULL,
		file_name VARCHAR(255),
		PRIMARY KEY(id),
		FOREIGN KEY (execution) REFERENCES executions(id) ON DELETE CASCADE
	)");

	$self->{dbh}->do("CREATE TABLE jobs (
		id INT NOT NULL,
		trace INT NOT NULL,
		job_number INT,
		submit_time INT,
		wait_time INT,
		run_time INT,
		allocated_cpus INT,
		avg_cpu_time INT,
		used_mem INT,
		requested_cpus INT,
		requested_time INT,
		requested_mem INT,
		status INT,
		uid INT,
		gid INT,
		exec_number INT,
		queue_number INT,
		partition_number INT,
		prec_job_number INT,
		think_time_prec_job INT,
		PRIMARY KEY (id),
		FOREIGN KEY (trace) REFERENCES traces(id) ON DELETE CASCADE
	)");
}

sub add_execution {
	my $self = shift;
	my $execution = shift;

	my $key_string = join (',', keys %{$execution});
	my $values_string = join (',', values %{$execution});
	$self->{dbh}->do("INSERT INTO executions ($key_string) values ($values_string)");
}

1;
