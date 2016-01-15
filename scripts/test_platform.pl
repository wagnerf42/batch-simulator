#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Log::Log4perl qw(get_logger :no_extra_logdie_message);

use Platform;

use Parse::RecDescent;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('test');

my $bla = '((1,1),(1,(1,1)))';

my $grammar = q {
	startrule: '(' content ',' content ')'
	content: startrule | /\d*/
};

my $parser = Parse::RecDescent->new($grammar) or die 'bad grammar';

$parser->startrule($bla) or print "bad text\n";

die;

my ($levels) = @ARGV;

my @level_parts = split('-', $levels);
my @available_cpus = (0..($level_parts[-1] - 1));

# Put everything in the log file
$logger->info("platform: @level_parts");

my $platform = Platform->new(\@level_parts, \@available_cpus, 1);
$platform->build_structure();
$platform->choose_cpus(9);

$logger->info("script finished");

sub get_log_file {
	return "log/generate_platform.log";
}


