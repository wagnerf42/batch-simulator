package Util;
use strict;
use warnings;

use Exporter qw(import);

our @EXPORT = qw(FALSE TRUE float_equal float_precision DEFAULT_PRECISION);

sub git_tree_dirty {
	my $git_branch = `git symbolic-ref --short HEAD`;
	chomp($git_branch);
	return ($git_branch eq 'master' and system('git diff-files --quiet')) ? 1 : 0;
}

use constant {
	FALSE => 0,
	TRUE => 1
};

use constant {
	DEFAULT_PRECISION => 6
};

sub float_equal {
	my $a = shift;
	my $b = shift;
	my $precision = shift;

	$precision = DEFAULT_PRECISION unless defined $precision;

	#return sprintf("%.${precision}g", $a) eq sprintf("%.${precision}g", $b);
	return abs($a - $b) < 10 ** -$precision;
}

sub float_precision {
	my $a = shift;
	my $precision = shift;

	$precision = DEFAULT_PRECISION unless defined $precision;

	return sprintf("%.${precision}g", $a);
}

1;
