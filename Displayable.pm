package Displayable;

use strict;
use warnings;

#my $user = $ENV{"USER"};
#my $dir = "/tmp/$user";
my $dir = 'svg';
mkdir $dir unless -f $dir;

my $file_count = 0;
sub tycat {
	my $self = shift;
	my $filename = shift;
	$filename = "$dir/$file_count.svg" unless defined $filename;
	$self->save_svg($filename, @_);
	`tycat $filename`;
	$file_count++;
	return;
}

1;
