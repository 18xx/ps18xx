#!perl

use strict;
use warnings;
use Getopt::Std;
use charnames ':full';

# Usage: concat [ -d src ] GTILES.ps		- Produce generic tile sheets
#		 concat [ -d src ] Txxx.ps			- Produce tile sheet for 18xxx
#		 concat [ -d src ] wTxxx.ps			- Ditto, alternative format
#		 concat [ -d src ] Pxxx.ps			- Ditto, for playable set
# 		 concat [ -d src ] Mxxx.ps			- Produce map for 18xxx
# 		 concat [ -d src ] yyy-MAP.ps xxx	- Produce map for game yyy of 18xxx
#
# Concatenate the components of various forms of maps and tile sheets
# for 18xx games in PostScript.  All need the files LICENCE,
# 18-pcode.ps, 18-defs.ps, and some bits of 18-gentl.ps, all of which
# are to be found in the directory src (. if not specified).  GTILES.ps
# needs src/18-gtlst.ps.  Txxx.ps needs src/xxx-tc.ps and
# src/18-talst.ps.  Mxxx.ps needs src/xxx-tc.ps, src/xxx-map.ps, and
# src/18-map.ps.  Game maps need the last three plus yyy-.ps (always
# from ., not src).
#
# In addition we calculate and supply various bits of glue.  For game
# maps if -t is specified also produce yyy-MAP.tl containing a list of
# available tiles.  Without switches, each tile is represemted by
# <tile number>/<count>.  Setting -e exchanges the number and count.  Setting
# -s replaces the / with a multiplication symbol.  Setting -i replaces the
# count with U when the tile is specified as unlimited.
#
# If -w is specified, make tile sheets in an alternative verbose format.  If -n
# is also specified the different orientations are shown numerically in
# addition to the usual compass points.
#
# We strip comments from all these files except LICENSE.
#
# In the tc file look for lines:
#	tileCodes <spec> [ <generic> ... //<colour> ... <count> ] put
#
# In the map file look for lines:
#	(...) [-]<spec> [ ... ] LayTile
#
# If making a blank map sheet and -a is specified, include all bits from
# the 18-gentl.ps which are needed to make up a game map.

# 1.1 Add version.  Fix case of 18xxvariant
# 1.2 Suppress numeric orientations in variant availability lists
# 1.3 Make tile sheets include all colours of tiles
# 1.4 Support non-numeric tile "numbers"
# 1.5 React more gracefully when trying to play undefined tiles
# 1.6 Put in support for checking tile upgrades & orientations
# 1.7 Emit warnings when more of a tile are used than in play
# 1.8 Rework previous warning scheme
# 1.9 Detect bad orientation data; make tile sheets fit on a page
# 1.10 React more gracefully when trying to play undefined tiles
# 1.11 Warn about mismatched parentheses in token lists
# 1.12 Warn about placing too many or invalid tokens; support new privates
# 1.13 Add support for printing tile sheets for cutting out
# 1.14 Suppress warnings for too many tiles when really unlimited.
# 1.15 5/2/11 Cutting-out tile sheets are 28 tiles per page
# 1.16 6/2/11 Fix LayFlash lines
# 1.17 24/2/11 Support -e, -i, -s to enhance *-MAP.tl files
# 1.18 26/3/11 Upgrade checking on Upgrade lines; fix balanced par check

my $version = "concat 1.18 26/3/11";

use constant GENERICTILESPERROW => 8;
use constant GENERICROWSPERPAGE => 9;
use constant TILESHEETSTANDINGTILESPERROW => 9;
use constant TILESHEETSITTINGTILESPERROW => 8;
use constant TILESHEETSTANDINGROWSPERPAGE => 9;
use constant TILESHEETSITTINGROWSPERPAGE => 10;
use constant ALTTILESHEETSTANDINGTILESPERROW => 17;
use constant ALTTILESHEETSITTINGTILESPERROW => 15;
use constant ALTROWSPERPAGE => 3;

sub printOut(@);
sub roundUpDivide($$);
sub countGtileSheets($);
sub copyFile($$$);
sub copyMapFile($$$;$);
sub noteTokens($$);
sub checkTokens();
sub copyTileFile($$);
sub processTileFile($$);
sub matchOrients($$$);
sub processMapFile($);
sub filterGenericTiles($);
sub openOutput($@);
sub closeOutput();
sub produceGTILES($);
sub produceMAP($);
sub produceTILE($);
sub produceGMAP($$);
sub processGENTL();
sub outputProlog($);
sub outputSetup();
sub outputEOF();
sub findColour($);

my %opts;
$opts{d} = ".";
getopts ('ad:einstvw', \%opts);

die "$version\n" if $opts{v};

if ($opts{w}) {
	$opts{w} = 3;
}

my %tileMap;
my @tileInUse;
my %coordMap;	# Tiles at each coordinate
my %tokens;		# List of coordinates for each token
my %maxTokens;	# Max allowed tokens
my @privates;	# LayPrivate/LayFlash lines
my @unlimited;	# Tiles of which there's an unlimited supply

my @tileColours = qw(Ground Yellow Green Brown Russet Gray Red
	SpecialArea Copper Blue Barr Pyjama NoHex Transparent);
my $ncolours;

my %legalUpgrades = (
	Ground => [ "Yellow" ],
	Yellow => [ "Green" ],
	Green => [ "Brown", "Russet" ],
	Brown => [ "Gray" ],
	);
my %upgradeList;

my $tileSitting = 0;
my @standingOrients = qw(SW W NW NE E SE);
my @sittingOrients = qw(S SW NW N NE SE);
my @numOrients = qw(0 1 2 3 4 5);

my @outList;

die "concat: not enough args\n" if $#ARGV < 0;
die "concat: too many args\n" if $#ARGV > 1;
if ($#ARGV == 0)
{
	if ($ARGV[0] =~ /GTILES\.ps/)
	{
		produceGTILES($ARGV[0]);
	}
	elsif ($ARGV[0] =~ /^M.*\.ps$/)
	{
		produceMAP($ARGV[0]);
	}
	elsif ($ARGV[0] =~ /^T.*\.ps$/)
	{
		produceTILE($ARGV[0]);
	}
	elsif ($ARGV[0] =~ /^w\d*T.*\.ps$/)
	{
		($opts{w}) = ($ARGV[0] =~ /^w(\d*)T.*\.ps$/);
		$opts{w} = ($opts{w} or 3);
		produceTILE($ARGV[0]);
	}
	elsif ($ARGV[0] =~ /^P.*\.ps$/)
	{
		$opts{p} = 1;
		produceTILE($ARGV[0]);
	}
	else
	{
		die "concat.pl: malformed argument\n";
	}
}
else
{
	die "concat.pl: malformed argument\n" unless $ARGV[0] =~ /MAP\.ps$/;
	produceGMAP($ARGV[0], $ARGV[1]);
}

sub printOut(@)
{
	for my $fh (@outList) {
		print $fh @_;
	}
}

sub roundUpDivide ($$) {
	my ($dividend, $divisor) = @_;
	return int (($dividend + $divisor - 1) / $divisor);
}

# Count the number of pages required to print the generic tiles.  There
# are GENERICTIlESPERROW * GENERICROWSPERPAGE tiles per page.  Make a
# note of which tile number starts each page.
sub countGtileSheets($) {
	my ($genericTilesRef) = @_;
	my $tiles = keys %$genericTilesRef;
	my $tilesPerPage = GENERICTILESPERROW * GENERICROWSPERPAGE;
	my $pages = roundUpDivide($tiles, $tilesPerPage);
	my @indices = map { $_*$tilesPerPage } 0 .. $pages - 1;
	return (sort keys %$genericTilesRef)[@indices];
}

# Copy input file to all the output files.
# If strip is true, strip out comments and blank lines.
sub copyFile($$$) {
	my ($dir, $file, $strip) = @_;
	my $handle;

	open $handle, "<$dir/$file" or die "Unable to open $dir/$file: $!\n";
	while (<$handle>) {
		s/(^|\s+)%.*// if $strip;	# Remove comments
		s/^(\s*)#/$1%/ if $strip;	# Switch comment characters
		s/\s*$/\n/ if $strip;		# Remove trailing white space

		if (my ($trans) = /^\/tlTransparent\s+(\d+)\s+def$/)
		{
			$ncolours = $trans;
			print STDERR "Warning: \@tileColours is out of date\n"
				unless ($ncolours == $#tileColours);
		}

		printOut $_ unless /^$/ && $strip;
	}
	close $handle;
}

# Copy a map file, specified by the first two arguments, to the output(s).
# It's a bit of a misnomer, because the stuff parsed by an earlier call to
# processMapFile is generated from that, and not from the map file on this
# pass.  If we see the special matching string, generate the preprocessed
# statements and then recurse to copy the file specified by the optional
# argument.  See processMapFile for the splitmarks argument.
sub copyMapFile($$$;$) {
	my ($dir, $file, $splitmarks, $include) = @_;
	my $handle;

	open $handle, "<$dir/$file" or die "Unable to open $dir/$file: $!\n";
	while (<$handle>) {
		my $match = /INSERT YOUR TILES AND TOKENS HERE/;

		s/(^|\s+)%.*//;	# Remove comments
		s/^(\s*)#/$1%/;	# Switch comment characters
		s/\s*$/\n/;		# Remove trailing white space

		if (@$splitmarks > 0) {
			my $mark = $$splitmarks[0];
			if (/^$mark/) {
				s/^$mark\s*//;
				for my $i (1..@$splitmarks - 1) {
					my $part = $$splitmarks[$i];
					if (/^$part/) {
						s/^$part\s*//;
						my $fh = $outList[$i - 1];
						print $fh $_;
					}
				}
				next;
			}
		}
		next if /LayTile/;
		next if /LayPrivate\s*/;
		next if /LayFlash\s*/;
		printOut $_ unless /^$/;
		next unless $match;
		for my $k (keys %coordMap) {
			next if $coordMap{$k}{valid}[0]->[1] eq '';
			for my $t (@{$coordMap{$k}{valid}}) {
				printOut "($k/$t->[0]) $t->[1]$tileMap{$t->[2]}->{idx} ",
					"[$t->[3]] LayTile\n";
				noteTokens($t->[3], $k);
			}
		}
		for my $p (@privates) {
			printOut $p;
		}
		for my $k (keys %coordMap) {
			next unless $coordMap{$k}{valid}[0]->[1] eq '';
			for my $t (@{$coordMap{$k}{valid}}) {
				printOut "($k/$t->[0]) $t->[1]$tileMap{$t->[2]}->{idx} ",
					"[$t->[3]] LayTile\n";
				noteTokens($t->[3], $k);
			}
		}
		copyMapFile ".", $include, [] if defined $include;
	}
	close $handle;
}

# Add the tokens provided on to the memorised list
sub noteTokens($$) {
	my ($toks, $key) = @_;
	return if $toks eq '';
	$toks =~ s/\(#[^)]*\)//g;			# Eliminate city names
	$toks =~ s/\\\(|\\\)|\(|\)/ /g;		# Eliminate parentheses
	$toks =~ s/^\s*//;					# ... leading white space
	$toks =~ s/\s*$//;					# ... and trailing ...
	$toks = uc $toks;
	for my $token (split " ", $toks) {
		next if $token =~ /^\s*$/;
		next if $token =~ /^-$/;
		push @{$tokens{$token}}, $key;
	}
}

# Check that the tokens printed are reasonable.
sub checkTokens() {
	# If we have no data, we can do nothing.
	if (!%maxTokens) {
		return;
	}
	for my $t (sort keys %tokens) {
		# Warn about tokens that we don't know about.
		if (!defined ($maxTokens{$t})) {
			print STDOUT "Unknown token $t found at coordinates ";
			for my $k (sort @{$tokens{$t}}) {
				print STDOUT "$k ";
			}
			print STDOUT "\n";
		}
		# Warn about excessive tokens.
		elsif (@{$tokens{$t}} > $maxTokens{$t}) {
			print STDOUT "Token $t found at coordinates ";
			for my $k (sort @{$tokens{$t}}) {
				print STDOUT "$k ";
			}
			print STDOUT "but only $maxTokens{$t} ";
			print STDOUT $maxTokens{$t} == 1 ? "is" : "are";
			print STDOUT " supplied\n";
		}
	}
}


# Copy a tile definition file.  We always suppress comments and white space.
# We also suppress the actual tile definitions, substituting a processed set
# obtained by an earlier call to processTileFile.  And we also substitute the
# definition of the size of the array of tile definitions.  In practice this
# doesn't leave a great deal of the original file!
sub copyTileFile($$) {
	my ($dir, $file) = @_;
	my $handle;

	open $handle, "<$dir/$file" or die "Unable to open $dir/$file: $!\n";
	while (<$handle>) {
		s/(^|\s+)%.*//;	# Remove comments
		s/^(\s*)#/$1%/;	# Switch comment characters
		s/\s*$/\n/;		# Remove trailing white space

		next if /^\s*tileCodes\s+/ and /\s+put\s*$/;
		if (/^\s*\/maxTile\s*\d+\s*def\s*$/) {
			printOut "/maxTile ", 1+scalar(keys(%tileMap)), " def\n";
			next;
		}
		printOut $_ unless /^$/;
	}
	my $idx = 1;
	foreach my $k (sort {
			$a =~ /^\d+$/ && $b =~ /^\d+$/ ?
				$a <=> $b : $a cmp $b
			} keys %tileMap) {
		my $t = $tileMap{$k};
		$t->{idx} = $idx;
		printOut "tileCodes $idx [ $t->{generic} $t->{orient} ",
		"//tl$t->{colour} //tl$t->{terrain} ($t->{label}) ($t->{value}) ",
		"$t->{count} ($t->{spec}) ] put\n";
		$idx++;
	}
	close $handle;
}


sub processTileFile ($$) {
	my ($file, $doingTileSheet) = @_;
	my %colours;
	my $rows = 0;

	open TC, "<$file" or die "Unable to open $file: $!\n";
	while (<TC>) {
		if (/^\s*%\s*Upgrades:\s*.*\s*->\s*.*\s*$/) {
			my ($col, $repl) = /^\s*%\s*Upgrades:\s*(\w*)\s*->\s*(\w*)\s*$/;

			$legalUpgrades{$col} = [] unless defined $legalUpgrades{$col};
			push @{$legalUpgrades{$col}}, $repl;
		}

		if (my ($class, $from, $to) =
				/^\s*%\s*Upgrade\s+(\w+)\s+(\w+)\s+=>\s+(.*)$/) {
			for my $t (split /\s+/, $to) {
				my ($repl, $o) = split /\//, $t;
				if ($o =~ /^\*$|^[0-5]+$|^=[0-5]+$/) {
					print STDERR "SYSTEM: Redefined upgrade in $_\n"
						if defined $upgradeList{$class}{$from}{$repl};
					$upgradeList{$class}{$from}{$repl} = $o;
				} else {
					print STDERR "SYSTEM: Bad orientation $o in $_\n";
				}
			}
		}

		if (my ($token, $count) = /^\s*%\s*Token\s+(\S+)\s+(\d+)\s*$/) {
			$token = uc $token;
			print STDERR "Warning: resetting count of $token from ",
				"$maxTokens{$token} to $count\n"
					if defined ($maxTokens{$token});
			$maxTokens{$token} = $count;
		}

		if (my ($list) = /^\s*%\s*Unlimited\s+(.+?)\s*$/) {
			push @unlimited, split ' ', $list;
		}

		s/(^|\s*)%.*//;		# Strip comments
		if (/\/tileSitting\s+true\s*def/) {
			$tileSitting = 1;
		}
		next unless /^\s*tileCodes\s+/;
		next unless /\s+put\s*$/;

		warn "Warning: unparseable tileCodes line"
			unless my ($spec, $generic, $orient, $colour, $terrain,
				$label, $value, $count) =
				/^\s*tileCodes\s+(\w+)\s+\[\s+(\d+)\s+(\d+)\s+\/\/tl(\S+)\s+\/\/tl(\S+)\s+\((.*)\)\s+\((.*)\)\s+(\d+)\s+\]\s+put\s*$/;

		if (defined $tileMap{$spec}) {
				warn "Warning: duplicate definition for tile #$spec";
		}

		$tileMap{$spec} = {
			spec => $spec,
			generic => $generic,
			orient => $orient,
			colour => $colour,
			terrain => $terrain,
			label => $label,
			value => $value,
			count => $count,
			used => 0
		};
		$tileInUse[$generic] = 1 if $doingTileSheet && $count > 0;
		$colours{$colour} += 1 if $count > 0;
	}
	close TC;
	$tileInUse[0] = 1;	# Tile 000 is always in use
	if ($opts{p}) {
		my $tiles = 0;
		for my $spec (keys %tileMap) {
			$tiles += $tileMap{$spec}{count};
		}
		return roundUpDivide($tiles, 28);
	} elsif ($opts{w}) {
		my $tc = 0;
		for my $colour (keys %colours) {
			$tc += $colours{$colour};
		}
		my $xSide = $tileSitting ? 2 : 2 * cos(30 * atan2(1,1) * 4 / 180);
		my $xDist = 2 * $xSide + 0.15;
		my $tilesPerRow = int(17.5 * $opts{w} / 0.8 / $xDist);

		$rows += roundUpDivide($tc, $tilesPerRow);
		return roundUpDivide($rows, $opts{w});
	} else {
		for my $colour (keys %colours) {
			$rows += roundUpDivide($colours{$colour},
				$tileSitting ? TILESHEETSITTINGTILESPERROW :
							   TILESHEETSTANDINGTILESPERROW);
		}
	}
	return roundUpDivide($rows, $tileSitting ?
		TILESHEETSITTINGROWSPERPAGE : TILESHEETSTANDINGROWSPERPAGE);
}

sub matchOrients ($$$) {
	my ($old, $new, $choices) = @_;
	my $oldAsNumber = -1;
	my $newAsNumber = -1;
	my $exact = 0;

	# If the supplied $choices is '*', we'll take anything.
	return 1 if $choices eq '*';

	# If $choices starts with '=', exact matches only
	if (substr($choices, 0, 1) eq '=') {
		$exact = 1;
		substr($choices, 0, 1) = '';
	}

	# Work out the numeric equivalent of the orientations.  We know, because
	# we've checked, that the orientations are valid.
	if ($old =~ /\d/) {
		$oldAsNumber = $old;
	} else {
		foreach my $i (0..5) {
			if (($tileSitting ? $sittingOrients[$i] :
				$standingOrients[$i]) eq uc $old) {
				$oldAsNumber = $i;
				last;
			}
		}
	}
	return 0 if $oldAsNumber < 0;
	if ($new =~ /\d/) {
		$newAsNumber = $new;
	} else {
		foreach my $i (0..5) {
			if (($tileSitting ? $sittingOrients[$i] :
				$standingOrients[$i]) eq uc $new) {
				$newAsNumber = $i;
				last;
			}
		}
	}
	return 0 if $newAsNumber < 0;
	if ($exact) {
		foreach my $i (split //, $choices) {
			return 1 if $i == $newAsNumber;
		}
	} else {
		foreach my $i (split //, $choices) {
			return 1 if ($oldAsNumber + $i) % 6 == $newAsNumber;
		}
	}
	return 0;
}

sub processMapFile ($) {
	my ($file) = @_;
	my ($coord, $orient, $use, $number, $tokens, $class);
	my @splitmarks;

	open MAP_H, "<$file" or die "Unable to open $file: $!\n";
	while (<MAP_H>) {
		if (/^%SPLIT\s*/) {
			s/^%SPLIT\s*//;
			@splitmarks = split(' ');
			next;
		}
		if (($coord, $orient, $use, $number, $tokens, $class) =
/^\s*\((.*)\/(.*)\)\s*(-?)(\w+)\s*\[(.*)\]\s*LayTile((?:\s*%\s*\S*)?)\s*$/
				) {
			$coord = uc $coord;
			$class =~ s/^\s*%\s*//;
		} else {
			s/(^|\s+)%.*//;	# Remove comments (in case LayTile is in a comment)
			if (/LayTile/) {
				print STDERR "Malformed line reading LayTile: $.\n";
				print STDERR "Line: $_";
			}
			if (/LayPrivate\s*/ or /LayFlash\s*/) {
				push @privates, $_;
			}
			next;
		}

		# If the tile we're laying hasn't been defined, make up a dummy
		# definition.
		unless (defined $tileMap{$number}) {
			$tileMap{$number} = {
				generic => 0,
				spec => $number,
				orient => 0,
				colour => "Ground",
				terrain => "Plain",
				label => "",
				value => "",
				count => 0,
				used => 0
			};
		}

		# Are we laying an undefined tile?
		print STDERR
			"Warning: Placing undefined tile #$use$number at coord $coord\n"
			unless $tileMap{$number}{generic} > 0;

		# Check that the orientation makes sense
		print STDERR "Warning: odd orientation $orient at coord $coord\n"
			unless grep {$_ eq uc $orient}
				$tileSitting ? @sittingOrients : @standingOrients,
				@numOrients;

		{
		our $np;
		$np = qr/\s*\((?:(?>[^()]+)|(??{$np}))*\)\s*/;
		print STDERR "Warning: unbalanced parentheses in \[$tokens\]\n"
			unless $tokens =~ /^($np)*$/;
		}

		unless (defined $coordMap{$coord}) {
			# This is the first reference to this coordinate.  Make sure
			# that it's a background tile.
			print STDERR "Warning: Placing player tile #$use$number (",
				$tileMap{$number}{colour}, ") at coord ", $coord, "\n"
				unless $use eq '-';
			# And that it's opaque
			print STDERR "Warning: Placing transparent tile #",
				"$use$number at coord $coord\n"
				if $tileMap{$number}{colour} eq "Transparent";
			$coordMap{$coord} = {
				valid => [ [ $orient, $use, $number, $tokens, $class ] ],
				class => $class,
				orient => $orient,
			}
		}
		elsif ($tileMap{$number}{colour} eq "Transparent") {
			# We're adding a transparent tile to some pile.  Just add it.
			push @{$coordMap{$coord}{valid}},
				[ $orient, $use, $number, $tokens, $class ];
		}
		else {
			# At this point we're replacing a pile of tiles described by
			# $coordMap{$coord}{valid} with one numbered $number.  If
			# there's more than one old tile, the first is the
			# non-transparent one that we need to examine closely.
			# Check that this is a legal thing to do.
			my $tile = $coordMap{$coord}{valid}[0];
			my $oo = $tile->[0];	# Old orientation
			my $ou = $tile->[1];	# Old use flag
			my $t = $tile->[2];		# Old tile number

			if (($class = $coordMap{$coord}{class}) ne "") {
				# We're replacing an old tile $t, of class $class to $number.
				# Make sure that this is legal.
				if (!defined $upgradeList{$class} or
					!defined $upgradeList{$class}{$t} or
					!defined $upgradeList{$class}{$t}{$number}) {
					print STDERR "Warning: Dubious upgrade of #$ou",
						"$t (", $tileMap{$t}{colour},
					   	") to #", $use, $number, " (",
						$tileMap{$number}{colour},
						") at coord ", $coord, "\n"
						unless $use eq '-';
				} else {
					print STDERR "Warning: Dubious upgrade orientation of #",
						"$ou$t/$oo (", $tileMap{$t}{colour}, ") to #", $use,
						$number, "/$orient (", $tileMap{$number}{colour},
						") at coord ", $coord, "\n"
						unless matchOrients($oo, $orient,
								$upgradeList{$class}{$t}{$number});
				}
			} else {
				# We don't have any class information, so we're relying on
				# old-fashioned technology.  Just check that the colours match.
				print STDERR "Warning: Upgrading #", $ou, $t, " (",
					$tileMap{$t}{colour}, ") to #", $number, " (",
					$tileMap{$number}{colour}, ") at coord $coord\n"
					unless grep {$_ eq $tileMap{$number}{colour}}
						@{$legalUpgrades{$tileMap{$t}{colour}}}
						or $use eq '-';
			}
			foreach my $s (@{$coordMap{$coord}{valid}}) {
				# We're replacing tiles here, so decrement the number of
				# times we've used an instance of this tile.
				$tileMap{$s->[2]}{used}-- unless $s->[1] eq '-';
			}
			$coordMap{$coord}{valid} =
				[ [ $orient, $use, $number, $tokens, $class ] ];
			$coordMap{$coord}{orient} = $orient;
		}
		$tileInUse[$tileMap{$number}{generic}] = 1;
		unless ($use eq "-") {
			# Warn about cases where we've used more tiles than are in the set
			if (++$tileMap{$number}{used} > $tileMap{$number}{count}) {
				unless (grep { $number eq $_ } @unlimited) {
					print STDERR
						"Warning: Tile #$number used in coords $coord ";
					for my $k (sort keys %coordMap) {
						next if $k eq $coord;
						for my $i (@{$coordMap{$k}{valid}}) {
							if ($i->[2] eq $number) {
								print STDERR "$k ";
							}
						}
					}
					print STDERR
						"but only $tileMap{$number}{count} are supplied\n";
				}
			}
		}
	}
	close MAP_H;
	return @splitmarks;
}

sub filterGenericTiles ($) {
	my ($genericTilesRef) = @_;

	for my $tile (sort keys %$genericTilesRef) {
		my ($tileNo) = $tile =~ m!^/Tile_(\d\d\d)\s+\{!;
		printOut $genericTilesRef->{$tile} if $tileInUse[$tileNo];
	}
}

sub produceGTILES ($) {
	my ($file) = @_;
	my $genericTilesRef = processGENTL();
	my @gTilePageStarts = countGtileSheets($genericTilesRef);
	openOutput($file);
	outputProlog(@gTilePageStarts);
	printOut "/18xxVariant (none) def\n";
	copyFile $opts{d}, "LICENSE", 0;
	copyFile $opts{d}, "18-pcode.ps", 1;
	copyFile $opts{d}, "18-defs.ps", 1;
	for my $tile (sort keys %$genericTilesRef) {
		printOut $genericTilesRef->{$tile};
	}
	copyFile $opts{d}, "18-gtlst.ps", 1;
	outputSetup();
	my $pageNo = 1;
	for (@gTilePageStarts) {
		my ($tileNo) = m!^/Tile_(\d\d\d)\s+{!;
		$tileNo += 0;
		printOut "\%\%Page: gen$pageNo $pageNo\n";
		printOut "$tileNo $pageNo ", 1+$#gTilePageStarts, " GenericTiles pop\n";
		printOut "showpage\n";
		$pageNo++;
	}
	outputEOF();
	closeOutput();
}

sub produceMAP ($) {
	my ($file) = @_;
	my ($var) = $file =~ /^M(.*)\.ps$/;
	$var = lc $var;
	my $vartc = $var . "-tc.ps";
	my $varmap = $var . "-map.ps";
	processTileFile "$opts{d}/$vartc", $opts{a} ? 1 : 0;
	my @splitmarks = processMapFile "$opts{d}/$varmap";
	my $genericTilesRef = processGENTL();
	openOutput($file, @splitmarks);
	outputProlog(1);
	printOut "/18xxVariant (18$var) def\n";
	copyFile $opts{d}, "LICENSE", 0;
	copyFile $opts{d}, "18-pcode.ps", 1;
	copyFile $opts{d}, "18-defs.ps", 1;
	copyFile $opts{d}, "18-map.ps", 1;
	filterGenericTiles($genericTilesRef);
	outputSetup();
	printOut "%%Page: map 1\n";
	copyTileFile $opts{d}, $vartc;
	copyMapFile $opts{d}, $varmap, \@splitmarks;
	checkTokens();
	printOut "showpage\n";
	outputEOF();
	closeOutput();
}

# Produce a tile sheet for the specified game.
# The file argument looks like Txx.ps; the variant is xx.
sub produceTILE ($) {
	my ($file) = @_;
	my $var;
	if ($opts{p}) {
		($var) = $file =~ /^P(.*)\.ps$/;
	} else {
		($var) = $file =~ /^w?\d*T(.*)\.ps$/;
	}
	$var = lc $var;
	my $vartc = $var . "-tc.ps";
	my $pages = processTileFile "$opts{d}/$vartc", 1;
	my $genericTilesRef = processGENTL();
	openOutput($file);
	outputProlog($pages);
	printOut "/18xxVariant (18$var) def\n";
	if ($opts{n}) {
		printOut "/orientNumbers true def\n";
	} else {
		printOut "/orientNumbers false def\n";
	}

	copyFile $opts{d}, "LICENSE", 0;
	copyFile $opts{d}, "18-pcode.ps", 1;
	copyFile $opts{d}, "18-defs.ps", 1;
	printOut "/nColours $ncolours def\n";
	copyFile $opts{d}, "18-talst.ps", 1;
	copyTileFile $opts{d}, $vartc;
	filterGenericTiles($genericTilesRef);
	outputSetup();
	for (my $pageNo = 1; $pageNo <= $pages; $pageNo++) {
		printOut "%%Page: tiles $pageNo\n";
		printOut $pageNo-1, " ", $pages;
		if ($opts{p}) {
			printOut " cuttingTileAvailability\n";
		} elsif ($opts{w}) {
			printOut " $opts{w} VariantTileAvailability\n";
		} else {
			printOut " TileAvailability\n";
		}
		printOut "showpage\n";
	}
	outputEOF();
	closeOutput();
}

sub produceGMAP ($$) {
	my ($file, $var) = @_;
	$var = lc $var;
	my $vartc = $var . "-tc.ps";
	my $varmap = $var . "-map.ps";
	my ($gm) = $file =~ /(.*)MAP\.ps/;
	$gm .= ".ps";
	processTileFile "$opts{d}/$vartc", 0;
	my @splitmarks = processMapFile "$opts{d}/$varmap";
	processMapFile $gm;
	my $genericTilesRef = processGENTL();
	openOutput($file, @splitmarks);
	outputProlog(1);
	printOut "/18xxVariant (18$var) def\n";
	copyFile $opts{d}, "LICENSE", 0;
	copyFile $opts{d}, "18-pcode.ps", 1;
	copyFile $opts{d}, "18-defs.ps", 1;
	copyFile $opts{d}, "18-map.ps", 1;
	filterGenericTiles($genericTilesRef);
	outputSetup();
	printOut "%%Page: map 1\n";
	copyTileFile $opts{d}, $vartc;
	copyMapFile $opts{d}, $varmap, \@splitmarks, $gm;
	checkTokens();
	printOut "showpage\n";
	outputEOF();
	closeOutput();

	return unless $opts{t};

	# Output a list of available tiles.  For each colour of tile in the
	# game, print a line containing the colour plus tile numbers and the
	# count of tiles left to be used.
	die "Can't make tiles left\n" unless $file =~ s/\.ps$/\.tl/;
	openOutput($file);

	# Make a list of all tiles, of all colours, with non-zero counts.
	my @allTiles = grep { $_->{count} > 0} values %tileMap;
	for my $col (@tileColours) {
		# Make a list of tiles of the right colour, sorted by tile
		# number, with the number of each remaining.  This is very
		# perlish, and gives programming a bad name.
		my @availableTiles =
			map {
				my $left = $_->{count} - $_->{used};
				my $number = $_->{spec};
				$left = "U" if $opts{i} and (grep { $number eq $_ } @unlimited);
				my $sep = $opts{s} ? "\N{MULTIPLICATION SIGN}" : '/';
				$opts{s} ? "$left$sep$_->{spec}" : "$_->{spec}$sep$left"
			}
				sort { $a->{spec} =~ /^\d+$/ && $b->{spec} =~ /^\d+$/ ?
					$a->{spec} <=> $b->{spec} : $a->{spec} cmp $b->{spec}
 				}
					grep { $_->{colour} eq $col } @allTiles;
		printOut $col, " ", (join " ", @availableTiles), "\n"
			if @availableTiles;
	}
	closeOutput();
}

sub processGENTL () {
	open GENTL, "<$opts{d}/18-gentl.ps"
   		or die "Unable to open $opts{d}/18-gentl.ps: $!\n";
	my $currentTile = "";
	my %genericTiles;

	while (<GENTL>) {
		s/(^|\s+)%.*//;		# Strip comments
		s/\s*$/\n/;			# Strip trailing white space
		next if /^$/;		# Strip blank lines
		$currentTile = $_ if m!^/Tile_\d\d\d\s+\{!;
		$genericTiles{$currentTile} .= $_ if $currentTile;
	}
	close GENTL;
	return \%genericTiles;
}

# Open one or more output files.  If splitmarks is empty, we simply
# open the supplied file name and push the file handle on to outList.
# If splitmarks is non-empty, we throw away the first element and open
# one file handle for each other element.  The name of the file is the
# supplied one with the element of splitmarks inserted before the last
# dot.  For example, if splitmarks is (MARK, 1, 2, 3) and we supply
# FILE.ps, we open FILE1.ps, FILE2.ps, and FILE3.ps.
sub openOutput ($@) {
	my ($file, @splitmarks) = @_;
	if (@splitmarks == 0) {
		my $fh;
		open $fh, ">$file" or die "unable to open output file $!\n";
		push @outList, $fh;
	} else {
		shift @splitmarks;
		for my $splitmark (@splitmarks) {
			my @nameparts = split /\./, $file;
			splice (@nameparts, -1, 0, $splitmark, ".");
			my $newfile = join "", @nameparts;
			my $fh;
			open $fh, ">$newfile" or die "unable to open output file $!\n";
			push @outList, $fh;
		}
	}
}

# Close all the output filehandles in the external outList
sub closeOutput()
{
	for my $fh (@outList) {
		close $fh;
	}
	@outList = ();
}

sub outputProlog ($) {
	my ($pages) = @_;
	printOut "%!PS-Adobe-3.0\n";
	printOut "%%Pages: $pages\n";
	printOut "%%EndComments\n";
	printOut "%%BeginProlog\n";
}

sub outputSetup () {
	printOut "%%EndProlog\n";
	printOut "%%BeginSetup\n";
	printOut "%%PaperSize: A4\n";
	printOut "%%EndSetup\n";
}

sub outputEOF () {
	printOut "%%EOF\n";
}

sub findColour ($) {
	my ($col) = @_;
	for (my $i = 0; $i < @tileColours; $i++) {
		return $i if $col eq $tileColours[$i];
	}
	warn "Warning: illegal colour $col";
}

