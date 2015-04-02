package Util;
use strict;
use warnings;

use Exporter qw(import);

our @EXPORT = qw(FALSE TRUE float_equal);

sub git_tree_dirty {
	my $git_branch = `git symbolic-ref --short HEAD`;
	chomp($git_branch);
	return ($git_branch eq 'master' and system('git diff-files --quiet')) ? 1 : 0;
}

use constant {
	FALSE => 0,
	TRUE => 1
};

sub float_equal {
	my $a = shift;
	my $b = shift;
	my $precision = shift;

	#return sprintf("%.${precision}g", $a) eq sprintf("%.${precision}g", $b);
	return abs($a - $b) < 10 ** -$precision;
}

1;
