#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Data::Dumper;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('compare_platform');

my ($communication_filename, $cost_filename, $permutations_filename) = @ARGV;

#open(my $communication_file, '<', $communication_filename) or $logger->logdie("unable to open communication file at $communication_file");

$logger->info("using communication file $communication_filename");
$logger->info("using cost file $cost_filename");
$logger->info("using permutations file $permutations_filename");

my @cost_matrix = read_cost();

open(my $permutations_file, '<', $permutations_filename) or $logger->logdie("unable to open permutations file at $permutations_filename");

while (my $permutation = <$permutations_file>) {
	chomp($permutation);
	my $communication_score = calculate_score($permutation);
	print "$permutation $communication_score\n";
}

sub calculate_score {
	my $permutation = shift;

	my $communication_score = 0;
	my @permutation_parts = split('-', $permutation);
	my $permutation_size = scalar @permutation_parts;

	open(my $communication_file, '<', $communication_filename) or $logger->logdie("unable to open communication file at $communication_filename");

	for my $cpu(0..($permutation_size - 1)) {
		my $line = <$communication_file>;
		chomp $line;
		my @cpu_communication = split(',', $line);
		my @cpu_cost = @{$cost_matrix[$permutation_parts[$cpu]]};
		for my $dst_cpu (0..($permutation_size - 1)) {
			$communication_score += $cpu_cost[$permutation_parts[$dst_cpu]] * $cpu_communication[$dst_cpu];
		}
	}

	return $communication_score;
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

