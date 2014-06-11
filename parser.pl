#!/usr/bin/perl

use strict;
use warnings;

use constant JOB_JUMBER => 0;
use constant SUBMIT_TIME => 1;
use constant WAIT_TIME => 2;
use constant RUN_TIME => 3;
use constant ALLOCATED_CPUS => 4;
use constant AVG_CPU_TIME => 5;
use constant USED_MEMORY => 6;
use constant REQUESTED_CPUS => 7;
use constant REQUESTED_TIME => 8;
use constant REQUESTED_MEMORY => 9;
use constant STATUS => 10;
use constant UID => 11;
use constant GID => 12;
use constant EXEC_NUMBER => 13;
use constant QUEUE_NUMBER => 14;
use constant PARTITION_NUMBER => 15;
use constant PREC_JOB_JUMBER => 16;
use constant THINK_TIME_PREC_JOB => 17;
use constant STATUS_COMPLETED => 1;
use constant STATUS_FAILED => 0;
use constant STATUS_CANCELLED => 5;

my @trace_data;
my @status_data;
my $job = 0;
my $partitions_count = 0;
my @partitions;

# Prints one status field line
sub print_status_field {
	my @fields = @_;
	shift @fields;
	print "@fields\n";
}

open (FILE, $ARGV[0]);

while (my $line = <FILE>) {
	my @fields = split(' ', $line);

	next unless defined $fields[0];
	
	# Status line
	if ($fields[0] eq ';') { 
		push @status_data, [@fields];

		next unless defined $fields[1];

		if ($fields[1] eq 'Partition:') {
			$partitions_count++;
		}

	}

	# Job line
	elsif ($fields[0] ne ' ') {
		push @trace_data, [@fields];
	}

}

print "Total jobs: " . scalar @trace_data . "\n";
print 'Total partitions: ' . $partitions_count . "\n";

for (my $i = 0; $i < $partitions_count; $i++) {
	$partitions[$i] = 0;
}

# Getting the partition names
my @partition_names;
my $status_index;
my $partition_index;

for ($status_index = 0; $status_index < @status_data; $status_index++) {
	next unless defined $status_data[$status_index][1];
	last if ($status_data[$status_index][1] eq 'Partition:');
}

for ($partition_index = 0; $status_index < @status_data and defined $status_data[$status_index][1] and $status_data[$status_index][1] eq 'Partition:'; $partition_index++, $status_index++) {
	$partition_names[$partition_index] = $status_data[$status_index][3];
}

# Counting how many times each partition is used. The partitions in the SWF 
# file start from 1 so I shift them one position
for (my $i = 0; $i < scalar @trace_data; $i++) {
	$partitions[$trace_data[$i][PARTITION_NUMBER] - 1]++;
}

for (my $i = 0; $i < $partitions_count; $i++) {
	next unless ($partitions[$i] > 0);
	print 'Partition ' . ($i + 1) . ': ' . $partition_names[$i] . ': ' . $partitions[$i] . ' job(s)' . "\n";
}

# Counting the number of jobs that finishe before, exactly at or after the
# requested time
my $j = 0, my $k = 0, my $l = 0;
for (my $i = 0; $i < @trace_data; $i++) {
	if ($trace_data[$i][RUN_TIME] < $trace_data[$i][REQUESTED_TIME]) {
		$j++;
	}

	elsif ($trace_data[$i][RUN_TIME] == $trace_data[$i][REQUESTED_TIME]) {
		$k++;
	}

	else {
		$l++;
	}
}

print 'Jobs executed less then requested time: ' . "$j\n";
print 'Jobs executed exactly the requested time: ' . "$k\n";
print 'Jobs executed more then requested time: ' . "$l\n";

# Counting the number of jobs that finished with the different status
for (my $i = 0, $j = 0, $k = 0, $l = 0; $i < @trace_data; $i++) {
	if ($trace_data[$i][STATUS] == STATUS_COMPLETED) {
		$j++;
	}

	elsif ($trace_data[$i][STATUS] == STATUS_FAILED) {
		$k++;
	}

	else {
		$l++;
	}
}
	
print 'Jobs finished with status = COMPLETED: ' . "$j\n";
print 'Jobs finished with status = FAILED: ' . "$k\n";
print 'Jobs finished with status = CANCELLED: ' . "$l\n";


close (FILE);
exit;
