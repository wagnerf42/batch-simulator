#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Data::Dumper;
use List::Util qw(max sum);

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('compare_platform');

my ($communication_filename, $cost_filename, $permutations_filename) = @ARGV;

my @alpha_values=(1, 0.75, 0.5, 0.25, 0);
my @alpha_strings = map { 'alpha' . $_ } (@alpha_values);

$logger->info("using communication file $communication_filename");
$logger->info("using cost file $cost_filename");
$logger->info("using permutations file $permutations_filename");

my @cost_matrix = read_cost();
my @comm_matrix = read_comm_matrix();

open(my $permutations_file, '<', $permutations_filename) or $logger->logdie("unable to open permutations file at $permutations_filename");


print "PERMUTATION max sum " . join(' ', @alpha_strings) . "\n";

while (my $permutation = <$permutations_file>) {
	chomp($permutation);
	my ($max_score, $sum_score) = calculate_score($permutation);
	my @combined_values = map {$_ * $max_score + (1 - $_) * $sum_score} (@alpha_values);
	print "$permutation $max_score $sum_score " . join(' ', @combined_values) . "\n";
}

sub calculate_score {
	my $permutation = shift;

	my @communication_score;
	my @permutation_parts = split('-', $permutation);
	my $permutation_size = scalar @permutation_parts;

	for my $cpu(0..($permutation_size - 1)) {
		# Cost of communication from this host
		# MPI CPU $cpu is in host $permutation_parts[$cpu]
		my @cpu_cost = @{$cost_matrix[$permutation_parts[$cpu]]};
		my @cpu_communication = @{$comm_matrix[$cpu]};

		$communication_score[$cpu] = 0;

		for my $dst_cpu (0..($permutation_size - 1)) {
			$communication_score[$cpu] += $cpu_cost[$permutation_parts[$dst_cpu]] * $cpu_communication[$dst_cpu];
		}
	}

	return (max(@communication_score), sum(@communication_score));
}

sub read_comm_matrix {
	my @comm_matrix;

	open(my $communication_file, '<', $communication_filename) or $logger->logdie("unable to open communication file at $communication_filename");

	while (my $line = <$communication_file>) {
		chomp $line;
		my @cpu_communication = split(' ', $line);
		push @comm_matrix, [@cpu_communication];
	}

	return @comm_matrix;
}

sub read_cost {
	my @cost_matrix;

	open(my $cost_file, '<', $cost_filename) or $logger->logdie("unable to open cost file at $cost_filename");

	while (my $line = <$cost_file>) {
		chomp $line;
		my @cpu_cost_matrix = split(' ', $line);
		push @cost_matrix, [@cpu_cost_matrix];
	}

	return @cost_matrix;
}

sub get_log_file {
	return "log/permutation_latency.log";
}

