#!/usr/bin/env perl
use strict;
use warnings;

use Algorithm::Permute;
use Algorithm::Combinatorics qw(combinations);
use Data::Dumper;
use Log::Log4perl qw(get_logger :no_extra_logdie_message);

use Platform;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('generate_permutations');

while (<>) {
	chomp;
	my @cpus = split('-', $_);
	my $iterator = Algorithm::Permute->new(\@cpus);
	while (my @permutation = $iterator->next()) {
		print join('-', @permutation) . "\n";
	}
}

sub get_log_file {
	return "log/generate_permutations.log";
}


