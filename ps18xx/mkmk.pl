#!perl

use strict;
use warnings;
use Getopt::Std;
use PsConfig;

# Usage: mkmk [-einst] [ -d src ] [-o out]
# Produce a Makefile for ps18xx
# Look in src directory (src if not specified) for files *-tc.ps where there is
# a corresponding *-map.ps file.
# Look in . for files of the form *-.ps.
# If any of -e, -i, -s, or -t is specified, that argument is passed on to
# invocations of concat.pl which should make game map files.
# If -n is specified, it is passed on to invocations of concat.pl which should
# make variant-format tile sheets.

# 1.1 ??/?/?? Add version.  React better in the face of malformed game files
# 1.2 ??/?/?? Support Pxx-style tile sheets
# 1.3 ??/?/?? Support titles with no tile sheets
# 1.4 27/1/11 Support titles with hyphens in their names
# 1.5 24/2/11 Use PsConfig; pass on -e, -s, -i to concat.pl
# 1.6  3/3/11 Handle cases where we have tiles but no map
# 1.7 11/3/11 Pass on -n, -t to concat.pl
# 1.8 18/6/13 Count the tiles

my $version = "mkmk 1.8 18/6/13";

getconfig('mkmk');
if ($#ARGV < 0) {
	if (defined $config{CustomaryArgs}) {
		unshift @ARGV, split " ", $config{CustomaryArgs};
	}
}
my %opts;
$opts{d} = "src";
$opts{o} = "-";
getopts ('d:eino:stv', \%opts);

die "$version\n" if $opts{v};

my %titles;
my %ntiles;
my %ntiletypes;

# Find the game titles we're going to use.  Glob the -tc files and find
# matching -map files.  The result is a hash where the keys are the titles of
# the games and the values are the name(s) of the output map files, and two
# more with the same keys and the values are the counts of layable tiles and
# the counts of types of layable tiles.
for my $tcfile (<$opts{d}/*-tc.ps>) {
    $tcfile = lc $tcfile;
	my $mapfile = $tcfile;
	$mapfile =~ s/-tc/-map/;
	my ($title) = $tcfile =~ /.*\/(.*)-tc\.ps$/;
	my @splitmarks;
	my $mapname;
	my $ntile = 0;
	my $ntiletype = 0;

	if (-e $mapfile) {
		# Slight complication.  If the file contains a line starting '%SPLIT'
		# then the result of running "concat.pl M<xx>.ps" is multiple output
		# files M<xx><suffix>.ps where the suffices are gleaned from the SPLIT
		# line.  So look in the map file for such lines.
		open MAP_H, "<$mapfile" or die "Unable to open $mapfile: $!\n";
		while (<MAP_H>) {
			if (/^%SPLIT\s*/) {
				s/^%SPLIT\s*//;
				@splitmarks = split(' ');
				last;
			}
		}
		close MAP_H;
		if (shift @splitmarks) {
			for my $mark (@splitmarks) {
				$mapname .= " " if $mapname;
				$mapname .= "M$title$mark.ps";
			}
		} else {
			# Simple: map file is just M<xx>.ps
			$mapname = "M$title.ps";
		}
		$titles{$title} = $mapname;
	} else {
		$titles{$title} = '';
	}
	# Another complication.  Some titles have no layable tiles, so don't bother
	# making Txx.ps etc.
	open TC_H, "<$tcfile" or die "Unable to open $mapfile: $!\n";
	while (<TC_H>) {
		next unless /^\s*tileCodes\s+/;
		next unless /\s+put\s*$/;
		warn "Warning: unparseable tileCodes line"
			unless my ($spec, $generic, $orient, $colour, $terrain,
				$label, $value, $count) =
				/^\s*tileCodes\s+(\w+)\s+\[\s+(\d+)\s+(\d+)\s+\/\/tl(\S+)\s+\/\/tl(\S+)\s+\((.*)\)\s+\((.*)\)\s+(\d+)\s+\]\s+put\s*$/;

		$ntile += $count;
		$ntiletype += 1 if $count > 0;
	}
	$ntiles{$title} = $ntile;
	$ntiletypes{$title} = $ntiletype;
}

# OK, loins are girded.  Now make the Makefile.

open OUT, ">$opts{o}" or die "unable to open output file $opts{o}: $!\n";

print OUT '# Warning: this is a generated file--do not hand-edit', "\n\n";
print OUT "SOURCES = src/LICENSE src/18-pcode.ps src/18-defs.ps src/18-gentl.ps\n";
print OUT "MAPSOURCES = src/18-map.ps\n";
print OUT "GENSOURCES = src/18-gtlst.ps\n";
print OUT "AVAILSOURCES	= src/18-talst.ps\n";
print OUT "\n";

print OUT "GENERATED = \\\n";
foreach my $title (sort keys %titles) {
	print OUT "\t";
	print OUT "$titles{$title} " if $titles{$title};
	print OUT "P$title.ps T$title.ps wT$title.ps w2T$title.ps "
		if $ntiles{$title} > 0;
	print OUT "\\\n";
}
print OUT "\tGTILES.ps\n";
print OUT "\n";

print OUT "all: \\\n";
foreach my $title (sort keys %titles) {
	print OUT "\t18$title \\\n";
}
print OUT "\tGTILES.ps\n";
print OUT "\n";

foreach my $title (sort keys %titles) {
	print OUT "18$title:";
	print OUT " $titles{$title}" if $titles{$title};
	print OUT " T$title.ps wT$title.ps w2T$title.ps"
		if $ntiles{$title} > 0;
	print OUT "\n";

	if ($titles{$title}) {
		print OUT "$titles{$title}: \$(SOURCES) \$(MAPSOURCES) src/$title-tc.ps src/$title-map.ps\n";
		print OUT "\t\@echo make $title map\n";
		print OUT "\tperl concat.pl -d src -a M$title.ps\n";
	}

	if ($ntiles{$title} > 0) {
		print OUT "P$title.ps: \$(SOURCES) \$(AVAILSOURCES) src/$title-tc.ps\n";
		print OUT "\t\@echo make $title playable tile list: ";
		print OUT "$ntiles{$title} tiles of $ntiletypes{$title} types\n";
		print OUT "\tperl concat.pl -d src \$\@\n";

		print OUT "T$title.ps: \$(SOURCES) \$(AVAILSOURCES) src/$title-tc.ps\n";
		print OUT "\t\@echo make $title tile list: ";
		print OUT "$ntiles{$title} tiles of $ntiletypes{$title} types\n";
		print OUT "\tperl concat.pl -d src \$\@\n";

		print OUT "wT$title.ps: \$(SOURCES) \$(AVAILSOURCES) src/$title-tc.ps\n";
		print OUT "\t\@echo make $title variant tile list: ";
		print OUT "$ntiles{$title} tiles of $ntiletypes{$title} types\n";
		print OUT "\tperl concat.pl ";
		print OUT "-n " if $opts{n};
		print OUT "-d src \$\@\n";

		print OUT "w2T$title.ps: \$(SOURCES) \$(AVAILSOURCES) src/$title-tc.ps\n";
		print OUT "\t\@echo make $title 2-up variant tile list: ";
		print OUT "$ntiles{$title} tiles of $ntiletypes{$title} types\n";
		print OUT "\tperl concat.pl ";
		print OUT "-n " if $opts{n};
		print OUT "-d src \$\@\n";
	}
	print OUT "\n";
}

print OUT "GTILES.ps: \$(SOURCES) \$(GENSOURCES)\n";
print OUT "\t\@echo make list of generic tiles\n";
print OUT "\tperl concat.pl -d src \$\@\n";
print OUT "\n";

print OUT "clean:\n";
print OUT "\tperl delete.pl -f *-MAP*.ps *.tl \$(GENERATED)\n";
print OUT "\n";

my $current = '';

for my $gmfile (<*-.ps>) {
	my ($var, $serial);
	open GM, "<", $gmfile or die "mkmk: can't open $gmfile";
	while (<GM>) {
		next unless (($var, $serial) = /^% Game file for 18([\w\-]+)(\w\d\d)$/) == 2;
		last;
	}
	close GM;

	unless (defined ($serial)) {
		print STDERR "Warning: Can't find variant name in $gmfile\n";
		next;
	}
	unless ($serial . "-.ps" eq $gmfile) {
		print STDERR "Warning: Serial number $serial doesn't match $gmfile\n";
		next;
	}

	(my $maps = $titles{$var}) =~ s/M$var/$serial-MAP/g;
	print OUT "$serial: $maps\n";
	print OUT "$maps: "; 
	print OUT "$serial-.ps \$(SOURCES) \$(MAPSOURCES) src/$var-tc.ps src/$var-map.ps\n";
	print OUT "\t\@echo \"make game status for $serial (variant $var)\"\n";
	print OUT "\tperl concat.pl ";
	print OUT "-t " if $opts{t};
	print OUT "-e " if $opts{e};
	print OUT "-i " if $opts{i};
	print OUT "-s " if $opts{s};
	print OUT "-d src $serial-MAP.ps $var\n";

	print OUT "\n";

	$current .= " $serial";
}

print OUT "current:$current\n";
print OUT "\n";

close OUT;

