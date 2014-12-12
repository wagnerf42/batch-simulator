package Util;
use strict;
use warnings;

use Exporter qw(import);

sub git_tree_dirty {
	my $git_branch = `git symbolic-ref --short HEAD`;
	chomp($git_branch);
	return ($git_branch eq 'master' and system('git diff-files --quiet')) ? 1 : 0;
}

use constant {
	FALSE => 0,
	TRUE => 1
};

our @EXPORT = qw(FALSE TRUE);

1;
