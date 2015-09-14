#!/usr/bin/env perl
use strict;
use warnings;

use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Data::Dumper;

my ($input_file) = @ARGV;

my $string;

{
	local $/ = undef;
	open(my $file, '<', $input_file) or die ('unable to open file');
	$string = <$file>;
	close $file;
}

my $file_base_name = `basename $input_file .log`;
my @file_name_parts = split('-', $file_base_name);
my $benchmark_name = $file_name_parts[0];

my ($simulated_time) = ($string =~ /Simulated time: (\d*\.\d*)/);
my ($simulation_time) = ($string =~ /simulation took (\d*\.\d*)/);
my ($computation_time) = ($string =~ /(\d*\.\d*) seconds were actual/);

print "$benchmark_name $simulated_time $simulation_time $computation_time\n";


