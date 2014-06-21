#!perl

use strict;
use warnings;
use Getopt::Std;
use PsConfig;

# Usage: oldgame [-d OldGames] [-mg] 18xxAdd
#
# Remove an existing game from the active list.
# 
# If -g is specified, move Add-.ps to OldMaps
#
# If -m is specified, remake Makefile to reflect the disappearance of
# the game.
#
# The old maps directory can be specified after -d.

# Change log:
#
# 1.1 8/3/10.  Take advantage of mkmk.pl
# 1.2 14/3/10. Take advantage of config
# 1.3 29/8/10. Check the contents of the file to make sure it's the right one.
#			   Get configuration for oldgame, not newgame!
# 1.4 28/2/11. Simplify calling sequence to mkmk.pl.

my $version = "oldgame 1.4 28/2/11";

getconfig('oldgame');
if ($#ARGV >= 0 && $ARGV[0] !~ /^-/) {
	if (defined $config{CustomaryArgs}) {
		unshift @ARGV, split " ", $config{CustomaryArgs};
	}
}
my %opts;
$opts{d} = "OldMaps";
getopts ('d:gmv', \%opts);
$opts{g} = $opts{m} = 1 unless $opts{g} or $opts{m};
die "$version\n" if $opts{v};

my $title;
my $serial;
my $mapfile;

die "oldgame: not enough args\n" if $#ARGV < 0;
die "oldgame: too many args\n" if $#ARGV > 0;
die "oldgame: cannot parse arg\n"
	unless (($title, $serial) = ($ARGV[0] =~ /^18(.*)([A-Za-z]\d*)$/));
$title = lc $title;
$serial = uc $serial;

if ($opts{g}) {
	$mapfile = $serial . "-.ps";
	die "oldgame: game map file does not exist\n" unless -e $mapfile;

	my ($var, $ser);
	open GM, "<", $mapfile or die "oldgame: can't open $mapfile";
	while (<GM>) {
		next unless (($var, $ser) = /^% Game file for 18(\w+)(\w\d\d)$/) == 2;
		last;
	}
	close GM;

	die "oldgame: Can't find variant name in $mapfile\n"
		unless (defined ($ser));
	die "oldgame: Serial number $ser found in $mapfile doesn't match\n"
		unless ($ser . "-.ps" eq $mapfile);
	die "oldgame: $mapfile is for 18$var, not 18$title\n"
		unless ($var eq $title);

	die "Can't move $mapfile to $opts{d}\n"
		unless rename $mapfile, "$opts{d}/$mapfile";
}

if ($opts{m}) {
	system "perl", "mkmk.pl";
}

