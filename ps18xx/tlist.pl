#!perl

use strict;
use Getopt::Std;

# Usage: tlist [-p] [ -d src ] [-o out]
# Look in src directory (. if not specified) for files *-tc.ps.
# In the tc file look for lines:
#	tileCodes <spec> [ <generic> <orientation> <colour> <terrain>
#		<value> <label> <count> ] put
# Most are numbers.  <colour> and <terrain> start "//tl".  <value> and
# <label> are surrounded by parentheses.
#
# Collect the data where count is non-zero, or where -p is specified,
# here pretending that <spec> is zero.  When done, sort the data and
# print.
# If -g is specified, sort data by generic tile.  If omitted, sort by
# specific tile number.
#

sub processTCFile ($);
sub printGeneric ($$);

my %opts;
$opts{d} = ".";
$opts{o} = "-";
getopts ('d:o:pg', \%opts);

open OUT, ">$opts{o}" or die "unable to open output file $opts{o}: $!\n";

my @tileList;
my @colours = qw(Ground Yellow Green Brown Russet Gray Red SpecialArea
	Copper Blue Barr Pyjama NoHex Transparent Ganges );
my @terrains = qw(Plain Water Water2 Water3 Mountain Mountain2 Hill
	HillWater MountainWater Water4 Alp Appennine Port Grass Tree Yucca
	Port2 Private PickShovel Mountain3);

for my $tcfile (<$opts{d}/*-tc.ps>) {
    $tcfile = lc $tcfile;

    processTCFile $tcfile;
}

my @sortedTiles;
if ($opts{g}) {
	@sortedTiles = sort {
		($a)->{generic} <=> ($b)->{generic} ||
		($a)->{spec} <=> ($b)->{spec} ||
		($a)->{spec} cmp ($b)->{spec} ||
		($a)->{colour} cmp ($b)->{colour} ||
		($a)->{terrain} cmp ($b)->{terrain} ||
		($a)->{value} <=> ($b)->{value} ||
		($a)->{value} cmp ($b)->{value} ||
		($a)->{label} cmp ($b)->{label} ||
		($a)->{orientation} <=> ($b)->{orientation} ||
		($a)->{game} cmp ($b)->{game}
	} @tileList;
} else {
	@sortedTiles = sort {
		($a)->{spec} <=> ($b)->{spec} ||
		($a)->{spec} cmp ($b)->{spec} ||
		($a)->{generic} <=> ($b)->{generic} ||
		($a)->{colour} cmp ($b)->{colour} ||
		($a)->{terrain} cmp ($b)->{terrain} ||
		($a)->{value} <=> ($b)->{value} ||
		($a)->{value} cmp ($b)->{value} ||
		($a)->{label} cmp ($b)->{label} ||
		($a)->{orientation} <=> ($b)->{orientation} ||
		($a)->{game} cmp ($b)->{game}
	} @tileList;
};


my $last;
my $lastspec;

for my $t (@sortedTiles) {
	my $this = join "", $t->{spec}, $t->{generic}, $t->{orientation},
		$t->{colour}, $t->{terrain}, $t->{value}, $t->{label};
	my $thisspec = $opts{g} ? $t->{generic} : $t->{spec};

	if ($lastspec ne $thisspec) {
		print OUT "\n" unless undef $lastspec;
	}
	if ($last eq $this) {
		print OUT ", ";
	} else {
		print OUT "\n" if $last;
		print OUT "$t->{spec} $t->{generic} $t->{orientation} $t->{colour} ";
		print OUT "$t->{terrain} " if $t->{terrain} && $t->{terrain} ne "Plain";
		print OUT "\$$t->{value} " if $t->{value};
		print OUT "\"$t->{label}\" " if $t->{label};
	}
	$last = $this;
	$lastspec = $thisspec;
	print OUT "$t->{game}";
}
print OUT "\n";
close OUT;

sub processTCFile ($) {
    my ($file) = @_;
    my $game = $file;
    $game =~ s/-tc\.ps$//i;
	$game =~ s/.*\///;
    $game =~ s/^/18/;

	return if $game eq "1830bc";
#	return if $game eq "1834";

    open TC, "<$file" or die "Unable to open $file: $!\n";
    while (<TC>) {
		s/%.*//;
		next unless /^\s*tileCodes\s+/;
		next unless /\s+put\s*$/;

		my ($spec, $generic, $orientation, $colour, $terrain, $label, $value, $count) =
		/^\s*tileCodes\s+(\w+)\s+\[\s+(\d+)\s+(\d+)\s+\/\/tl(\w+)\s+\/\/tl(\w+)\s+\((.*)\)\s+\((.*)\)\s+(\d+)\s+\]\s+put\s*$/;

		print OUT "Illegal colour $colour in $game\n"
			unless grep {$_ eq $colour} @colours;
		print OUT "Illegal terrain $terrain in $game\n"
			unless grep {$_ eq $terrain} @terrains;

		if ($opts{p}) {
			if ($count <= 0) {
				$spec = 0;
				$count = 1;
			}
		}
		if ($count > 0) {
			push @tileList, {
				spec => $spec,
				generic => $generic,
				orientation => $orientation,
				colour => $colour,
				terrain => $terrain,
				label => $label,
				value => $value,
				count => $count,
				game => $game
			};
   		}
	}
    close TC;
}
