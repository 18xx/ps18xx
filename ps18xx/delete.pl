#!perl

use strict;
use warnings;
use Getopt::Std;

my %opts;
getopts ('f', \%opts);

my @cannot = grep {not unlink} grep {-e } map {glob} @ARGV;
die "$0: could not remove @cannot\n", if @cannot and $opts{f};

