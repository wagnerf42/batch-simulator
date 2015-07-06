#!/usr/bin/env perl
use strict;
use warnings;

use Algorithm::Permute;
use Algorithm::Combinatorics qw(combinations);
use Data::Dumper;
use Log::Log4perl qw(get_logger :no_extra_logdie_message);

use Platform;

Log::Log4perl::init('log4perl.conf');

my $logger = get_logger('test');

my @available_cpus = (0..($levels[$#levels] - 1));
my $required_cpus = 4;
my $permutations_file_name = "permutations";
my $execution_id = 7;

open(my $file, '>', $permutations_file_name);

my $iterator = Algorithm::Permute->new(\@available_cpus);
while (my @permutation = $iterator->next()) {
	print $file join('-', @permutation) . "\n";
}

sub get_log_file {
	return "log/generate_permutations.log";
}


