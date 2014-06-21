#!perl

use strict;
use Getopt::Std;

# Usage: concord [ -d src ] [<generic> ...]
# Look in src directory (. if not specified) for files *-tc.ps.  For
# each such file find the corresponding *-map.ps file, if any.  In the
# tc file look for lines:
#	tileCodes <spec> [ <generic> ... <count> ] put
#
# In the map file look for lines:
#	(...) [-]<spec> [ ... ] LayTile
#
# We need to maintain a <spec> to <generic> mapping for use in
# determining the use of the map file information.  This mapping is
# created afresh for each tc/map file pair.  A generic tile is useful either if
# its count field in the tc file is greater than zero, or if the <spec>
# field in the map file references it in the tc file.

sub processTCFile ($\%);
sub processMapFile ($\%);
sub printGeneric ($$);

my %opts;
$opts{d} = ".";
$opts{o} = "-";
getopts ('d:o:', \%opts);

open OUT, ">$opts{o}" or die "unable to open output file $opts{o}: $!\n";

my @generic;
my %avail;

open GENTL, "<$opts{d}/18-gentl.ps"
    or die "Unable to open $opts{d}/18-gentl.ps: $!\n";
while (<GENTL>) {
    next unless m!^/Tile_\d\d\d\s+\{!;
    my ($tile) = m!^/Tile_(\d\d\d)\s+\{!;
    $avail{$tile + 0}++ if $tile > 0;
}
close GENTL;

for my $tcfile (<$opts{d}/*-tc.ps>) {
    $tcfile = lc $tcfile;
    my $mapfile = $tcfile;
    my %specmap = ();

    $mapfile =~ s/-tc\.ps$/-map.ps/i;

    processTCFile $tcfile, %specmap;
    processMapFile $mapfile, %specmap;
}

if (@ARGV) {
    for my $g (@ARGV) {
	printGeneric $g, $generic[$g];
    }
}
else {
    for my $i (0  .. $#generic) {
	printGeneric $i, $generic[$i] if $generic[$i];
    }
    for my $i (sort keys %avail) {
	print OUT "$i: not used\n" unless $generic[$i];
    }
}

sub processTCFile ($\%) {
    my ($file, $specref) = @_;

    open TC, "<$file" or die "Unable to open $file: $!\n";
    while (<TC>) {
	s/%.*//;
	next unless /^\s*tileCodes\s+/;
	next unless /\s+put\s*$/;

	my ($spec, $generic, $count) =
	/^\s*tileCodes\s+(\w+)\s+\[\s+(\d+)\s+.*\s+(\d+)\s+\]\s+put\s*$/;

	$specref->{$spec} = $generic;
	if ($count > 0) {
	    push @{$generic[$generic]}, $file;
	}
    }
    close TC;
}

sub processMapFile ($\%) {
    my ($file, $specref) = @_;

    open MAP, "<$file" or return;
    while (<MAP>) {
	s/%.*//;
	next unless /^\s*\(/;
	next unless /\s+LayTile\s*$/;

	my ($spec) = /^\s*\(.*?\)\s+-?(\w+)\s+\[.*\]\s+LayTile\s*$/;

	if (exists $specref->{$spec}) {
	    push @{$generic[$specref->{$spec}]}, $file;
	}
	else {
	    warn "Unable to find $spec in $file\n";
	    my $junk;
	    $junk = <STDIN>;
	}
    }
    close MAP;
}

sub printGeneric ($$) {
    my ($g, $ref) = @_;

    print OUT "$g: ";
    print OUT "not available!: " unless $avail{$g};
    if ($ref) {
	my @f;

	@f = map { m!.*/(.*)-(?:map|tc)\.ps$!i } @$ref;
	my $prev;
	for my $f (@f) {
	    next if $f eq $prev;
	    print OUT ", " if $prev;
	    print OUT "$f";
	    $prev = $f;
	}
	print OUT "\n";
    }
    else {
	print OUT "not found\n";
    }
}
