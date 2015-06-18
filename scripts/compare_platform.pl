#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Time::HiRes qw(time);
use Algorithm::Permute;
use Data::Dumper;

use Platform;

Log::Log4perl::init('log4perl.conf');

my $logger = get_logger('test');

my @levels = (1, 2, 4, 32);
my @available_cpus = (0..($levels[$#levels] - 1));

my $removed_cpus_number = 12;
my $required_cpus = 16;

for my $i (0..($removed_cpus_number - 1)) {
	my $position = int(rand($levels[$#levels] - 1 - $i));
	splice(@available_cpus, $position, 1);
}

$logger->debug("available cpus: @available_cpus");

my $platform = Platform->new(\@levels, \@available_cpus, 1);
$platform->build_structure();
my @combinations = $platform->generate_all_combinations($required_cpus);

print Dumper(@combinations);
die;

$platform->build_platform_xml();
$platform->save_platform_xml('/tmp/platform.xml');

for my $combination (@combinations) {
	my $iterator = Algorithm::Permute->new($combination);

	while (my @permutation = $iterator->next()) {
		print STDERR "permutation @permutation\n";
	}
}


