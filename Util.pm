package Util;
use strict;
use warnings;

sub git_tree_dirty {
	my $git_branch = `git symbolic-ref --short HEAD`;
	chomp($git_branch);
	return ($git_branch eq 'master' and system('git diff-files --quiet')) ? 1 : 0;
}

1;
