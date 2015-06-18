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

my @test = (1, 4, 3, 5, 4, 2);
write_host_file(\@test, 3);
die;

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
$platform->build_platform_xml();
$platform->save_platform_xml('/tmp/platform.xml');

my $iterator = Algorithm::Permute->new(\@available_cpus);

my $permutation_number = 0;

while (my @permutation = $iterator->next()) {
	$logger->debug("permutation @permutation");
	write_host_file(\@permutation, $permutation_number);
	$permutation_number++;
}

sub write_host_file {
	my $permutation = shift;

	my $permutation_file_name = "/tmp/permutation-$permutation_number";
	open(my $file, '>', $permutation_file_name);

	print $file "$_\n" for (@{$permutation});
	return;
}


