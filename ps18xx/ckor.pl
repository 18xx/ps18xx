#!perl

use strict;
use warnings;
use Getopt::Std;

# Usage: ckor [ -d SRC ] file ...
# Check that upgrade paths specified in the named files correspond to
# legal upgrades deduced from known connectivity.
#
# Parse the file conndata (in .) to learn about the connectivity of
# generic tiles.  Also, learn about which type mismatches are allowed.
# Look in SRC directory (SRC if not specified) for the named files
# (which are globbed, so *-tc.ps gets the lot).  In these files look for
# lines of the form:
#	tileCodes <spec> [ <generic> <or} ... ] put
# to get information about which tiles are in use Also look for lines
# that say
# 	% Upgrade <type> <from> => <to>/<or> ...
# and issue warnings about anything that looks dubious.

# Change log:
#
# 2.0 26/2/14.  New version.

my $version = "ckor v2.0 26/2/14";

sub processTCFile ($$);
sub processConnData ();
sub sanitiseConns($$$);
sub findLegalOrientations($$);
sub rot ($$);
sub isasubset ($$);
sub allthere ($$);
sub fiddleGauge ($);
		
my %opts;
$opts{d} = "SRC";
$opts{o} = "-";
getopts ('d:o:v', \%opts);

die "$version\n" if $opts{v};

open OUT, ">$opts{o}" or die "unable to open output file $opts{o}: $!\n";

my %generic;
my %or;
my %valid;
my @type;
my @conns;
my %types;

processConnData ();

for my $file (@ARGV) {
	my $url = $opts{d} . '/' .  $file;
	for my $tcfile (<$opts{d}/$file>) {
		undef %generic;
		undef %or;
		$tcfile = lc $tcfile;
		my ($title) = ($tcfile =~ /.*\/([^\/]*)-tc\.ps/);
		$title = '18' . $title;
		print OUT "Variant $title: $tcfile\n";
   		processTCFile $tcfile, $title;
	}
}

close OUT;

# processConnData: read and adsorb the contents of the file connData (in
# .).  Comments are introduced by '%'.  Each non-blank line is either
#	<title>: valid <from> <to>
# or
#	<no>: <type> <conns>
# The first type of line represents non-standard valid upgrade paths in
# the specified title.  The secodn represents the type of and the
# connections on the given generic tile.
sub processConnData () {
    open CD, "<connData" or die "Unable to open connData: $!\n";
    while (<CD>) {
		s/%.*//;
		next if /^\s*$/;
		if ((my ($title, $from, $to) =
				/^(.*):\s+valid\s+(\S+)\s+(\S+)\s*$/) == 3) {
			push @{$valid{$title}{$from}}, $to;
		} elsif ((my ($no, $type, $conns) =
				/^(\d*):\s+(\S+)\s+(\S+)\s*$/) == 3) {
			$type[$no] = $type;
			$conns[$no] = $conns;
			sanitiseConns($no, $type, $conns);
			$types{$type} = 0;
		} elsif ((($no, $type) =
				/^(\d*):\s+(\S+)\s*$/) == 2) {
			$type[$no] = $type;
			$conns[$no] = '';
			$types{$type} = 0;
		} else {
			print OUT "Cannot parse $_";
		}
	}
	close CD;
}

# sanitiseConns: verify that the given connections contain no characters
# other than digits, possibly preceded by 'n' or 'd', separated by '-',
# ',', or ';'.
# Also, check that if the connections come in groups, there are as many
# groups of types.
sub sanitiseConns($$$) {
	my ($no, $type, $conns) = @_;
	return
		if $conns eq '';
	my @n = split /;/, $conns;
	if (@n > 1) {
		my @t = split /\//, $type;
		print OUT "$no: Mismatch between $type and $conns\n"
			unless @n == @t;
	}
	for my $group (@n) {
		for my $cluster (split /,/, $group) {
			for my $edge (split /-/, $cluster) {
				print OUT "$no: rubbish in $conns\n"
					unless $edge =~ /^[dn]?[0-9]$/;
			}
		}
	}
}

sub processTCFile ($$) {
    my ($file, $title) = @_;
	my $found = 0;
	my $dud = 0;

    open TC, "<$file" or die "Unable to open $file: $!\n";
	# It's always valid to upgrade a tile type to itself
	for my $type (keys %types) {
		push @{$valid{$title}{$type}}, $type;
	}
    while (<TC>) {
		my $line = $_;
		if ((my ($spec, $generic, $or) =
			/^\s*tileCodes\s+(\w+)\s+\[\s+(\d+)\s+(\d)\s+.*\s+\]\s+put/
			) == 3) {
			unless (exists $type[$generic]) {
				print OUT "Missing data for $generic in connData: $line";
				$dud = 1;
				next;
			}
			$generic{$spec} = $generic;
			$or{$spec} = $or;
			next;
		}
		if ((my ($type, $from, $tos) =
			/^\s*%\s*Upgrade\s+(\w+)\s+(\w+)\s+=>\s+(.*)$/) == 3) {
			$found = 1;
			unless (exists $generic{$from}) {
				print OUT "Tile $from not defined: $line";
				$dud = 1;
				next;
			}
			if ($tos eq '') {
				print OUT "Missing upgrade destinations: $line";
				$dud = 1;
				next;
			}
			for (split " ", $tos) {
				my $to = $_;
				my ($tn, $tr);
				unless ((($tn, $tr) = ($to =~ /^(\w+)\/([0-5]+|=[0-5]+|\*)$/)) == 2) {
					print OUT "malformed upgrade destination $to\n";
					$dud = 1;
					next;
				}
				unless (exists $generic{$tn}) {
					print OUT "Tile $tn not defined: $line";
					$dud = 1;
					next;
				}
				# Verify that the types match
				my $ft = $type[$generic{$from}];
				my $tt = $type[$generic{$tn}];
				if ((grep { $_ eq $tt } @{$valid{$title}{$ft}}) == 0) {
					print OUT "Can't upgrade $ft to $tt: $line";
					$dud = 1;
				}
				# Verify that the orientations match
				if ($tr eq '*') {
					$tr = '012345';
				}
				if ($tr =~ /^=\d+$/) {
					print OUT "Can't check absolute orientation $tn/$tr: $line";
					$dud = 1;
					next;
				}
				my $fr = findLegalOrientations($from, $tn);
				if ($fr ne $tr ) {
					print OUT "$from: $tn/$fr doesn't match $tn/$tr: $line";
					$dud = 1;
					next;
				}
			}
			next;
		}
		s/%.*//;
		next if /^\s*$/;
		next if /18xxVariant/;
		next if /maxTile/;
		next if /tileSitting/;
		print OUT "Cannot parse $_";
		$dud = 1;
    }
    close TC;
	print OUT "No upgrade lines found\n"
		unless $found;
	print OUT "Upgrade lines are in order\n"
		if $found && !$dud;
}

# findLegalOrientations: return a string listing the legal orientations
# when upgrading from $from to $to.
sub findLegalOrientations($$) {
	my ($from, $to) = @_;
	my $gf = $generic{$from};
	my $of = $or{$from};
	my $gt = $generic{$to};
	my $ot = $or{$to};
	my $cf = rot($conns[$gf], $of);
	my $ct = rot($conns[$gt], $ot);
	my $r;
	my @l = 0..5;
	if ($ct =~ /;/) {
		# Complex case: the generic tile used by $to has more than one
		# (in practice always two) groups of connections of differing
		# types.  We insist that only matching edge types are used to
		# check maintenance of connectibity.
		# For example, if we're upgrading from City to City/Plain, we
		# insist that the City track on $from is a subset of the City
		# track on $to, and don't care about the Plain track.
		my @ctl = split /;/, $ct;
		my @ttl = split /\//, $type[$gt];
		my @cfl = split /;/, $cf;
		my @tfl = split /\//, $type[$gf];
		for my $i (0..$#cfl) {
			for my $j (0..$#ctl) {
				if ($tfl[$i] eq $ttl[$j]) {
					@l = grep { isasubset($cfl[$i], rot($ctl[$j], $_)) } @l;
				}
			}
		}
	} else {
		# Simple case: just check for subset.
		@l = grep { isasubset($cf, rot($ct, $_)) } @l;
	}
	$r = join '', @l;
	return $r;
}

# rot: rotate the connections iin $conns clockwise by $or.
sub rot ($$) {
	my ($conns, $or) = @_;
	return join '', map {$_ ge '0' && $_ le '5' ?
		'0' + (($_ + $or) % 6) : $_ } split //, $conns;
}

# isasubset: return 1 if all the connections in $from are to be fount
# somewhere amongst those of $to.  Otherwise return 0.
sub isasubset ($$) {
	my ($from, $to) = @_;
	my @fc = map {join '', sort split // }
		map { fiddleGauge($_) }
		map { scalar (s/-//g, $_) } split /[,;]/, $from;
	my @tc = map {join '', sort split // }
		map { fiddleGauge($_) }
		map { scalar (s/-//g, $_) } split /[,;]/, $to;
	for my $f (@fc) {
		if (!grep { allthere ($f, $_) } @tc) {
			return 0;
		}
	}
	return 1;
}

# allthere: return 1 if all the edges of $from are found in $to.  Allow
# upgrades from narrow gauge to narrow or dual, standard gauge to
# standard or dual, or dual to dual.
sub allthere ($$) {
	my ($from, $to) = @_;
	if ((grep { $to =~ /$_/} map {
		my $c = $_;
		$c =~ tr/012345ABCDEF/NOPQRSNOPQRS/;
		$_ =~ /[0-5A-F]/ ? '[' . $_ . $c . ']' : $_;
	} split //, $from) == length $from) {
		return 1
	}
	return 0;
}

# fiddleGauge: change the representation of narrow or dual gauge from
# two characters to one.
sub fiddleGauge ($) {
	my ($str) = @_;
	$str =~ s/n0/A/g;
	$str =~ s/n1/B/g;
	$str =~ s/n2/C/g;
	$str =~ s/n3/D/g;
	$str =~ s/n4/E/g;
	$str =~ s/n5/F/g;
	$str =~ s/d0/N/g;
	$str =~ s/d1/O/g;
	$str =~ s/d2/P/g;
	$str =~ s/d3/Q/g;
	$str =~ s/d4/R/g;
	$str =~ s/d5/S/g;
	return $str;
}
