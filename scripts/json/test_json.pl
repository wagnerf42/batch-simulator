#!/usr/bin/env perl
use warnings;
use strict;
use JSON;
use File::Slurp;
use Data::Dumper;

my $text = read_file($ARGV[0]);
my $var = decode_json($text);
print Data::Dumper->Dump([$var]);
