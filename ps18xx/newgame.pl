#!perl

use strict;
use warnings;
use Getopt::Std;
use PsConfig;

# Usage: newgame [-d src] [-gmt] 18xxAdd
#
# Set up all that is needed to start a new game.
#
# If -m is specified, bring Makefile up to date.  This won't actually do
# anything unless a new game file has been made lately.  If -k is also set,
# pass arguments on to mkmk.
#
# If -g is specified, create an empty game map file.  If -b count is
# also set, add count commented-out LayTile lines.
#
# If -t is set, create empty map and tile files.  If -e is also
# specified, edit the tile files to add the name of the game and the
# date.
#
# Under some circumstances we'll need stuff from a source directory.  If
# so, get it from src (default src).

# Change log:
#
# 1.1 10/4/08.  Introduce version number.  Add 1831FR.  Update current.
# 1.2 21/4/08.  Add some copycoords for 1848.
# 1.3 19/5/08.  Fix serial & round coordinates for 18AL.
# 1.4 15/6/08.  Add 1824 to list of supported games.
# 1.5 17/9/08.  Fix copycoords for 1861
# 1.6 14/1/09.  Add 1848A to list of supported games.
# 1.7 29/3/09.  Add 1812 to list of supported games.
# 1.8 1/4/09.   Add mine overlays to 1812.  Fix a bug in editing Games.mak when
#			    the game is one that's never been done before.
# 1.9 12/7/09.	Add Sunderland to copycoords in 1812.
# 1.10 14/9/09.	Add 1841v2 to list of supported games.
# 1.11 17/11/09	Fix copycoords for 1841 & 1841v2.
# 1.12 29/11/09	Fix overlays for 18C2C
# 1.13 16/12/09	Fix copycoords for 18West
# 1.14 4/2/10	Add support for 18FL
# 1.15 17/2/10	Add support for 1850
# 1.16 27/2/10	Add support for 1817, 18us.  Create empty Games.mak if needed
# 1.17 8/3/10	Make use of mkmk.
# 1.18 14/3/10	Make use of config.
# 1.19 18/3/10	In 1844, add overlays in hex K16.  Fix font size in 1850.
# 1.20 16/6/10	In 18fl, add overlays.
# 1.21 4/8/10	Add support for 1858
# 1.22 24/9/10	Fix copycoords for 18west.
# 1.23 2/10/10	Update overlays, copycoords for 1899v2, 18us.
# 1.24 13/11/10	Update overlays for 1812.
# 1.25 26/11/10	Add support for 18Ardennes (as 18ard).
# 1.26 2/12/10	Add support for Poseidon (as 1800BC).
# 1.27 27/1/11	Add support for 18FR-RCE
# 1.28 4/2/11	Add support for 1880
# 1.29 10/2/11	Add Newark to list of copycoords for 1812.
# 1.30 28/2/11	Simplify calling sequence to mkmk.pl.
# 1.31 28/3/11	Improve support for 1832.
# 1.32 25/1/12	Add support for 1761, 18NYC, 18PA.
# 1.33 25/11/12	Add support for 1822, 1843
# 1.34 16/12/12	Add support for 18EA
# 1.35 1/2/13	Add support for 18EA, reduce round font size in 18EA
# 1.36 15/6/13	Add support for 1865Sar
# 1.37 31/7/13	Support non-commented and oriented overlays
# 1.38 27/2/14	Add support for games we don't know.  Fix minor overlay bug
# 1.39 6/3/14	Move 1837 data to 37-map.ps

my $version = "Newgame v1.39 6/3/14";

sub fakeLayoutEntry($);

getconfig('newgame');
if ($#ARGV >= 0 && $ARGV[0] !~ /^-/) {
	if (defined $config{CustomaryArgs}) {
		unshift @ARGV, split " ", $config{CustomaryArgs};
	}
}
my %opts;
$opts{d} = "src";
getopts ('b:d:egmtv', \%opts);

die "$version\n" if $opts{v};

# Set up a database of things we know about various games.
my %layout = (
	"00bc" => {
		nameformat => "'%s",
		copycoords => [ qw( A7 A11 A13 A15 A17 A19 A21
			B10 B14 B16 B18 B20
			C1 C3 C11 C15 C17
			D2 D8 D10 D12 D16 D18
			E3 E5 E11 E17 E19
			F4 F12 F14 F18 F20
			G5 G9 G11 G13 G15 G17 G19 G21
			H6 H12 H16 H18 H20
			I5 I9 I19 I21
			J6 J10 J12 J14 J16 J18 J20
		) ],
		overlays => {
			A9 => 410,
			F10 => 411,
			C9 => 412,
			H8 => 413,
			E9 => 414,
			F8 => 415,
			D4 => 416,
			G7 => 417,
		},
		namefont => "/Bookman 80",
		namecoord => '@9',
		roundfont => "/Bookman 80",
		roundcoord => '@16',
	},
	"12" => {
		nameformat => "'%s",
		copycoords => [ qw( E4 D9 C14 E14 C20 F5 E20 ) ],
		overlays => {
			B15 => 440,
			D17 => 440,
			D7 => 440,
			E2 => 440,
			E6 => 440,
		},
		namefont => "/Bookman 80",
		namecoord => 'G4',
		roundfont => "/Bookman 80",
		roundcoord => 'G6',
	},
	"17" => {
		nameformat => "'%s",
		copycoords => [ qw( B5 B17 C8 C14 C22 C26 D7 D9 D19 E22 F3 F13 F19 G6 G18 H3 H9 I12 I16 ) ],
		namefont => "/Bookman 120",
		namecoord => 'H22',
		roundfont => "/Bookman 120",
		roundcoord => 'J18',
	},
	"22" => {
		nameformat => "'%s",
		copycoords => [ qw( A33 A39 B32 C3 C31 C33 D26 E21 E33 F2 F6 G21 G27 K33 ) ],
		overlays => {
			N32 => 482,
			N36 => 482,
			C15 => 482,
			B38 => 483,
			B34 => 484,
			D38 => 484,
			I37 => 484,
			J12 => 484,
			K37 => 484,
		},
		namefont => "/Bookman 120",
		namecoord => 'H5',
		roundfont => "/Bookman 120",
		roundcoord => 'H7',
	},
	"24" => {
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => '@9',
		roundfont => "/Bookman 120",
		roundcoord => '@17',
	},
	"25u2" => {
		nameformat => "%s",
		namefont => "/Bookman 90",
		namecoord => 'K19',
		roundfont => "/Bookman 90",
		roundcoord => 'L20',
	},
  "25u3" => {
    nameformat => "%s",
    namefont => "/Bookman 80",
    namecoord => 'A6',
    roundfont => "/Bookman 80",
    roundcoord => "A10",
  },
	"26" => {		# the name of the game
		copycoords => [ qw( C11 C13 E5 I7 K17 L14 M3 ) ],
					# the coordinates of lines we wish to copy
		nameformat => "'26%s",
					# the format of the serial number (%s for the
					# variable part of it)
		namefont => "/Bookman 80",
					# the fount to use for the serial number
		namecoord => "C0",
					# and where to put it
		roundfont => "/Bookman 80",
					# the fount to use for the round number (suppressed
					# if it's the same as for the serial number)
		roundcoord => "D0",
					# and where to put it
	},
	"30" => {
		copycoords => [ qw( D2 D14 ) ],
		nameformat => "1830%s",
		namefont => "/Bookman 80",
		namecoord => "K16",
		roundfont => "/Bookman 72",
		roundcoord => "H20",
	},
	"31fr" => {
		copycoords => [ qw( E1 E5 F24 I3 J30 K19 M9 M31 N4 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => "J2",
		roundfont => "/Bookman 120",
		roundcoord => "A8",
	},
	"32" => {
		copycoords => [ qw( O36 S22 W14 AA28 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => "V29",
		roundfont => "/Bookman 120",
		roundcoord => "X29",
	},
	"35" => {
		copycoords => [ qw( C11 E19 F12 F14 G5 H2 L14 ) ],
		nameformat => "1835%s",
		namefont => "/Bookman 60",
		namecoord => "K17",
		roundfont => "/Bookman 80",
		roundcoord => "L17",
	},
	"37sx" => {
		copycoords => [ "A3", "B18", "C13", "E5", "G27", "I15", "K11", "L6" ],
		nameformat => "'%s",
		namefont => "/Bookman 80",
		namecoord => "D14",
		roundfont => "/Bookman 80",
		roundcoord => "D22",
	},
	"41" => {
		copycoords => [ qw( C7 D8 D16 E7 E9 E11 F8 F14 F16 G13 G15
							H4 H8 H10 H12 J6 K11 K13 K15 L12 L14
							M3 M7 Q11 S11 P12 R14 ) ],
		nameformat => "1841%s",
		namefont => "/Bookman 80",
		namecoord => "T1",
		roundfont => "/Bookman 80",
		roundcoord => "T6",
	},
	"41v2" => {
		copycoords => [ qw( C7 D8 D16 E7 E9 E11 F8 F14 F16 G13 G15
							H4 H8 H10 H12 J6 K11 K13 K15 L12 L14
							M3 M7 Q11 S11 P12 R14 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => "U5",
		roundfont => "/Bookman 80",
		roundcoord => "R6",
	},
	"43" => {
		copycoords => [ qw( A6 C14 E16 H25 L15 K8 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => '@15',
		roundfont => "/Bookman 80",
		roundcoord => "A12",
	},
	"44" => {
		copycoords => [ "I6", "K2" ],
		overlays => {
			C22 => 465,
			D17 => 460,
			F9 => 463,
			F19 => 461,
			F27 => 462,
			G22 => 470,
			H15 => [ 468, 469 ],
			J15 => [ 466, 467 ],
			F21 => [ 472, 473, 474, 480, 481, 482, 483, 484 ],
			G16 => [ 472, 473, 474, 480, 481, 482, 483, 484 ],
			H9 => [ 472, 473, 474, 480, 481, 482, 483, 484 ],
			I16 => [ 472, 473, 474, 480, 481, 482, 483, 484 ],
			K32 => [ 472, 473, 474, 480, 481, 482, 483, 484 ],
			L15 => [ 472, 473, 474, 480, 481, 482, 483, 484 ],
			M24 => [ 472, 473, 474, 480, 481, 482, 483, 484 ],
			H19 => [ 475, 476, 477, 478, 479, 922 ],
			H21 => [ 464, 475, 476, 477, 478, 479, 923 ],
			H23 => [ 475, 476, 477, 478, 479, 924 ],
			H29 => [ 475, 476, 477, 478, 479 ],
			I14 => [ 475, 476, 477, 478, 479 ],
			I18 => [ 475, 476, 477, 478, 479, 921 ],
			J11 => [ 475, 476, 477, 478, 479 ],
			K16 => [ 475, 476, 477, 478, 479 ],
		},
		nameformat => "1844%s",
		namefont => "/Bookman 72",
		namecoord => "M28",
		roundfont => "/Bookman 72",
		roundcoord => "N28",
	},
	"46" => {
		copycoords => [ "D20", "E11", "H12", "I5" ],
		nameformat => "'%s",
		namefont => "/Bookman 80",
		namecoord => "C0",
		roundfont => "/Bookman 80",
		roundcoord => "J17",
	},
	"48" => {
		copycoords => [ qw( F39 H13 I40 L19 M13 M29 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => "Q8",
		roundfont => "/Bookman 80",
		roundcoord => "B33",
	},
	"48a" => {
		copycoords => [ qw( D1 ) ],
		overlays => {
			B19 => 441,
			F17 => 441,
			G6 => 441,
			H11 => 441,
		},
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => "K12",
		roundfont => "/Bookman 80",
		roundcoord => "I1",
	},
	"49v4" => {
		copycoords => [ "C1", "M9", "B14" ],
		overlays => {
			B2 => 450, D4 => 450, H6 => 450, J6 => 450,
			I7 => 450, H10 => 450, J10 => 450, K11 => 450,
			M11 => 450,
			E3 => 451, H4 => 451, I5 => 451, F6 => 451,
			G7 => 451, H8 => 451, G9 => 451,
			D2 => 452, F2 => 452, F4 => 452, E5 => 452,
			G5 => 452, F8 => 452, J8 => 452, E9 => 452,
			I9 => 452, K9 => 452, F10 => 452, L10 => 452,
			E11 => 452, G11 => 452, D12 => 452, L12 => 452,
		},
		nameformat => "'49%s",
		namefont => "/Bookman 80",
		namecoord => "K1",
		roundfont => "/Bookman 80",
		roundcoord => "M1",
	},
	"50" => {
		copycoords => [ qw( A2 B1 C20 F1 M2 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => "\@8",
		roundfont => "/Bookman 80",
		roundcoord => "\@14",
	},
	"51" => {
		nameformat => "1851%s",
		namefont => "/Bookman 50",
		namecoord => "\@6",
		roundfont => "/Bookman 50",
		roundcoord => "\@2",
	},
	"54" => {
		overlays => {
			E22 => 356,
			G16 => 356,
			G18 => 356,
			G20 => 356,
			G24 => 356,
			I10 => 356,
			J3 => 356,
			J15 => 356,
			K16 => 356,
		},
		nameformat => "1854%s",
		namefont => "/Bookman 120",
		namecoord => "B16",
		roundfont => "/Bookman 96",
		roundcoord => "C16",
	},
	"56" => {
		copycoords => [ "N11" ],
		nameformat => "1856%s",
		namefont => "/Bookman 80",
		namecoord => "E21",
		roundfont => "/Bookman 80",
		roundcoord => "J21",
	},
	"58" => {
		copycoords => [ qw( A14 B6 B9 C2 E18 E20 F1 G8 G10 G20 H3
			H11 H19 I2 K18 L7 L13 O8 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => "N16",
		roundfont => "/Bookman 120",
		roundcoord => "N19",
	},
	"60" => {
		nameformat => "'%s",
		namefont => "/Bookman 80",
		namecoord => "J12",
		roundfont => "/Bookman 80",
		roundcoord => "A2",
	},
	"60v2" => {
		nameformat => "%s",
		namefont => "/Bookman 80",
		namecoord => "J12",
		roundfont => "/Bookman 80",
		roundcoord => "A2",
	},
	"61" => {
		copycoords => [ qw( A4 C14 C20 D1 D9 F15 G8 G18 H13 H19 J7 J17 M10 P3 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 80",
		namecoord => "M18",
		roundfont => "/Bookman 80",
		roundcoord => "N20",
	},
	"62h" => {
		copycoords => [ "H29" ],
		nameformat => "1862H%s",
		namefont => "/Bookman 72",
		namecoord => "A11",
		roundfont => "/Bookman 72",
		roundcoord => "A21",
	},
	"65sar" => {
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => "G8",
		roundfont => "/Bookman 120",
		roundcoord => "G10",
	},
	"70" => {
		overlays => {
			N1 => [ 426, 431 ],
			A2 => 427,
			C18 => 428,
			A22 => 429,
			J5 => 430,
			N17 => [ 432, 435 ],
			J3 => 433,
			M22 => 434,
		},
		nameformat => "1870%s",
		namefont => "/Bookman 80",
		namecoord => "\@1",
		roundfont => "/Bookman 80",
		roundcoord => "\@17",
	},
	"80" => {
		copycoords => [ qw( A3 E13 H6 H14 P12 Q7 Q15 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => '@7',
		roundfont => "/Bookman 80",
		roundcoord => '@14',
	},
	"89" => {
		copycoords => [ "B7", "C4", "F9", "K4" ],
		nameformat => "'%s",
		namefont => "/Bookman 80",
		namecoord => "D14",
		roundfont => "/Bookman 72",
		roundcoord => "I14",
	},
	"90" => {
		nameformat => "1890%s",
		namefont => "/Bookman 80",
		namecoord => "I1",
		roundfont => "/Bookman 80",
		roundcoord => "J1",
	},
	"99v2" => {
		copycoords => [ qw( T0 L0 A1 L4 S5 Q7 E7 ) ],
		overlays => {
			E3 => 460,
			F4 => 460,
			U1 => 461,
			S1 => 461,
			T2 => 461,
		},
		nameformat => "'%s",
		namefont => "/Bookman 80",
		namecoord => "L9",
		roundfont => "/Bookman 80",
		roundcoord => "L10",
	},
	"al" => {
		copycoords => [ "H5", "K4" ],
		nameformat => "'%s",
		namefont => "/Bookman 60",
		namecoord => "T4",
		roundfont => "/Bookman 60",
		roundcoord => "T6",
	},
	"ard" => {
		copycoords => [ qw( A8 A16 C7 D18 E5 E9 E15 E25
	   						F10 G25 H6 I21 J24 K11 M7 M27 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 80",
		namecoord => "C19",
		roundfont => "/Bookman 80",
		roundcoord => "D24",
	},
	"c2c" => {
		overlays => {
			A4 => 484,
			C4 => [ 486, 506 ],
			D49 => 487,
			D63 => 475,
			D69 => 474,
			E4 => [ 473, 503 ],
			E88 => 497,
			F47 => 473,
			F75 => 474,
			F85 => 474,
			G2 => 474,
			H55 => [ 474, 507 ],
			H73 => 475,
			I70 => [ 473, 478 ],
			J57 => [ 490, 495, 496 ],
			J63 => 474,
			K20 => [ 474, 483 ],
			L29 => [ 473, 482, 505 ],
			L75 => 504,
			M52 => [ 473, 489, 498 ],
			M62 => 479,
			M74 => 501,
			N29 => 485,
			O4 => 488,
			O72 => [ 474, 480, 499 ],
			P5 => 475,
			P73 => 475,
			Q28 => 477,
			R9 => 473,
			S58 => 476,
			T13 => 502,
			T41 => 473,
			T43 => [ 473, 493 ],
			U22 => 475,
			U28 => [ 475, 491 ],
			U66 => 475,
			V57 => 475,
			W46 => 474,
			W56 => [ 492, 494, 500 ],
			W66 => 475,
			Y42 => 475,
			Z39 => 481
		},
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => "Z5",
		roundfont => "/Bookman 120",
		roundcoord => "Z13",
	},
	"c61" => {
		copycoords => [ qw( C7 D2 D4 H6 L2 L14 ) ],
		overlays => {
			'%C9/4' => '-X2',
			'%C11/1' => -5,
			'%D10/5' => -8,
			'%E11' => -58,
			'%F10/3' => -6,
			'%I5' => -58,
			'%J4' => -4,
			'%K3' => -9,
			'%K13/5' => -4,
			'%L10/4' => -141,
			'%L12/4' => -83,
		},
		nameformat => "'%s",
		namefont => "/Bookman 96",
		namecoord => "D15",
		roundfont => "/Bookman 96",
		roundcoord => "C15",
	},
	"ea" => {
		copycoords => [ qw( B15 D15 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => "I13",
		roundfont => "/Bookman 96",
		roundcoord => "I15",
	},
	"eu" => {
		copycoords => [ "J1", "E10", "N11" ],
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => "L14",
		roundfont => "/Bookman 96",
		roundcoord => "O14",
	},
	"fl" => {
		nameformat => "18FL%s",
		namefont => "/Bookman 120",
		namecoord => "G1",
		roundfont => "/Bookman 120",
		roundcoord => "I1",
		overlays => {
			B7 => [ 442, 444, 445, 446, 447, 448 ],
			B13 => [ 442, 444, 445, 446, 447, 448 ],
			B19 => [ 442, 444, 445, 446, 447, 448 ],
			C14 => [ 442, 444, 445, 446, 447, 448 ],
			C24 => [ 442, 444, 445, 446, 447, 448 ],
			D23 => [ 442, 444, 445, 446, 447, 448 ],
			D25 => [ 442, 444, 445, 446, 447, 448 ],
			E26 => [ 442, 444, 445, 446, 447, 448 ],
			I22 => [ 442, 444, 445, 446, 447, 448 ],
			I28 => [ 442, 444, 445, 446, 447, 448 ],
			M24 => [ 442, 444, 445, 446, 447, 448 ],
			B5 => 441,
			B15 => 441,
			B23 => 441,
			F23 => 441,
			G20 => 441,
			J27 => 441,
			K28 => 441,
		}
	},
	"fr-rce" => {
		copycoords => [ qw( A6 C14 E16 H25 L15 K8 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => '@15',
		roundfont => "/Bookman 80",
		roundcoord => "A12",
	},
	"ga" => {
		overlays => {
			F8 => 443,
		},
		nameformat => "'%s",
		namefont => "/Bookman 80",
		namecoord => "D14",
		roundfont => "/Bookman 60",
		roundcoord => "E14",
	},
	"gb" => {
		copycoords => [ qw( H9 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => '@4',
		roundfont => "/Bookman 120",
		roundcoord => '@6',
	},
	"gl" => {
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => "O3",
		roundfont => "/Bookman 80",
		roundcoord => "O6",
	},
	"mex" => {
		copycoords => [ qw( I12 B3 D11 Q14 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => "Q1",
		roundfont => "/Bookman 120",
		roundcoord => "S1",
	},
  "neb" => {
		copycoords => [ qw( I12 B3 D11 Q14 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 70",
		namecoord => "A11",
		roundfont => "/Bookman 80",
		roundcoord => "A13",
  },
	"nyc" => {
		copycoords => [ qw( E3 F20 J20 ) ],
		overlays => {
			B12 => 457,
			C11 => 457,
			C23 => 457,
			D18 => 457,
			D20 => 457,
			E9 => 457,
			F10 => 457,
			F12 => 457,
			G9 => 457,
			G13 => 457,
			G19 => 457,
			G21 => 457,
			I19 => 457,
			I23 => 457,
			J18 => 457,
			J22 => 457,
			K19 => 457
		},
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => "C1",
		roundfont => "/Bookman 96",
		roundcoord => "J1",
	},
	"pa" => {
		copycoords => [ qw( D29 G28 H25 H27 K4 M16 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 96",
		namecoord => "M8",
		roundfont => "/Bookman 96",
		roundcoord => "M25",
	},
	"scan" => {
		copycoords => [ qw( A4 F1 F11 G2 G4 H13 H17 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 80",
		namecoord => "C20",
		roundfont => "/Bookman 80",
		roundcoord => "G18",
	},
	"soh" => {
		nameformat => "'%s",
		namefont => "/Bookman 80",
		namecoord => "B1",
		roundfont => "/Bookman 80",
		roundcoord => "C1",
	},
	"tn" => {
		copycoords => [ "B13", "G6", "H15" ],
		nameformat => "'%s",
		namefont => "/Bookman 80",
		namecoord => "B6",
		roundfont => "/Bookman 72",
		roundcoord => "B18",
	},
	"us" => {
		copycoords => [ qw( E2 G4 H17 J5 J8 J11 J14 J17 J20 J23 ) ],
		overlays => {
			A4 => 344,
			A6 => 344,
			A8 => 344,
			A10 => 344,
			A12 => 344,
			A14 => 344,
			A16 => 344,
			A18 => 344,
		},
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => '@9',
		roundfont => "/Bookman 120",
		roundcoord => '@16',
	},
	"va" => {
		copycoords => [ "A8", "E8", "M8", "O8", "F1", "L1", "O2", "Q6" ],
		overlays => {
			C8 => 430,
			E6 => 430,
			K6 => 430,
			M6 => 430,
		},
		nameformat => "'%s",
		namefont => "/Bookman 120",
		namecoord => "?5",
		roundfont => "/Bookman 72",
		roundcoord => "A1",
	},
	"west" => {
		copycoords => [ qw( A4 B3 D23 E26 F21 F25 F27 G2 G14 G22
			H25 I4 I26 J5 K20 L21 ) ],
		nameformat => "'%s",
		namefont => "/Bookman 80",
		namecoord => "C26",
		roundfont => "/Bookman 72",
		roundcoord => "D27",
	},
);

# Parse the argument into the title of the game (xx) and the serial
# number (a letter and some digits).

my $title;
my $serial;
my $mapfile;

die "newgame: not enough args\n" if $#ARGV < 0;
die "newgame: too many args\n" if $#ARGV > 0;
die "newgame: cannot parse arg\n"
	unless (($title, $serial) = ($ARGV[0] =~ /^1[78](.*)([A-Za-z]\d*)$/));
$title = lc $title;
$serial = uc $serial;
if ($ARGV[0] =~ /^1761/) {
	$title = 'c61';
}
if ($opts{g}) {
	fakeLayoutEntry($title)
		unless exists $layout{$title};
	die "newgame: don't know how to make game map file\n"
		unless exists $layout{$title};
	$mapfile = $serial . "-.ps";
	die "newgame: game map file already exists\n" if -e "data/$mapfile";

	# Now create a suitable game map file.
	if (exists $layout{$title}{copycoords}) {
		open SRCFILE, "<$opts{d}/$title-map.ps"
			or die "Unable to open $opts{d}/$title-map.ps: $!\n";
	}
	if (exists $layout{$title}{overlays}) {
		open TCFILE, "<$opts{d}/$title-tc.ps"
			or die "Unable to open $opts{d}/$title-tc.ps: $!\n";
	}
	open MAPFILE, ">$mapfile" or die "Unable to open $mapfile: $!\n";
	print MAPFILE "% Game file for 18$title$serial\n";

	if (exists $layout{$title}{copycoords}) {
		while (<SRCFILE>) {
			s/(^|\s+)%.*//;	# Remove comments
			next unless /^\s*\(.+\/.+\)\s*-?\d+\s*\[.*\]\s*LayTile$/;
			my ($coord) = /^\s*\((.+)\/.+\)/;
			if (grep { $_ eq $coord } @{$layout{$title}{copycoords}}) {
				print MAPFILE "\%";
				print MAPFILE $_;
			}
		}
		close SRCFILE;
	}
	if (exists $layout{$title}{overlays}) {
		my %table;
		while (<TCFILE>) {
			next unless (my ($no, $terrain, $label, $value) =
			/^\s*tileCodes\s*(\w+)\s*\[\s*\d+\s*\d\s*.*\s*\/\/tl([A-Za-z\d]*)\s*\((.*)\)\s*\((.*)\)\s*\d+\s*\]\s*put$/);
			$table{$no} = join ',', $terrain, $label, $value;
			for ($table{$no}) {
				s/^Plain//;
				s/^,*//;
				s/,*$//;
			}
		}
		close TCFILE;
		for my $key (sort keys %{$layout{$title}{overlays}}) {
			my $val = $layout{$title}{overlays}{$key};
			my ($comm, $tile, $or) = ($key =~ /^(%?)([^%\/]*)(\/\w+)?$/);
			$comm = $comm eq '%' ? '' : '%';
			if (!defined($or) || $or eq '') {
				$or = '/0';
			}
			for my $no (ref $val ? @$val : $val) {
				my ($m, $n) = ($no =~ /^(-?)([^-]*)$/);
				$m = $m eq '-' ? '' : '-';
				print MAPFILE
					"$comm\t($tile$or)\t$m$n\t[]\tLayTile";
				print MAPFILE "\t\% $table{$n}"
					if exists $table{$n};
				print MAPFILE "\n";
			}
		}
	}

	print MAPFILE "\n\n";
	if ($opts{b}) {
		for (1 .. $opts{b}) {
			my $line = ($config{BlankLine} or "\%\t()\t\t\[\]\tLayTile\n");
			print MAPFILE $line;
		}
		print MAPFILE "\n\n";
	}
	print MAPFILE "\t\t$layout{$title}{namefont} selectfont\n";
	print MAPFILE "\t($layout{$title}{namecoord}/7) LayText moveto (";
	printf MAPFILE $layout{$title}{nameformat}, $serial;
	print MAPFILE ") show\n";
	print MAPFILE "\t\t$layout{$title}{roundfont} selectfont\n"
		unless $layout{$title}{namefont} eq $layout{$title}{roundfont};
	print MAPFILE "\t($layout{$title}{roundcoord}/7) LayText moveto (start) show\n";

	close MAPFILE;
}

if ($opts{m}) {
	system "perl", "mkmk.pl";
}

if ($opts{t}) {
	system "make", "18$title";
	if ($opts{e}) {
		my @tilefiles = glob("w*T$title.ps");
		push @tilefiles, "T$title.ps" if -e "T$title.ps";

		my @months = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun",
			"Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );
		my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
			localtime;
		$mon = $months[$mon];
		$year += 1900;

		my $repl = "($serial $mday/$mon/$year) show";

		for my $file (@tilefiles) {
			die "newgame: can't open $file"
				 unless open SRC, "<", $file;
			my $f;
			{
				local $/;
				$f = <SRC>;
			}
			close SRC;
			die "newgame: can't find hook in $file"
				unless $f =~ s/(Tile Availability:.*show)/$1 $repl/g;
			my $outfile = $file;
			$outfile =~ s/$title/-$serial/;
			die "newgame: $outfile already exists" if -e $outfile;
			die "newgame: can't open $outfile"
				unless open OUTFILE, ">", "$outfile";
			print OUTFILE $f;
			close OUTFILE;
		}
	}
}

# Fake entry in layout
# Look in src/$title-map.ps for appropriate lines, and fake up an entry
# in the layout dataset from the information supplied.
# Mandatory entries are nameformat, namefont, namecoord, roundfont, and
# roundcoord.  Optional entries are copycoords and overlays.
#
# % newgame: nameformat: string
# % newgame: namefont: string
# % newgame: namecoord: string
# % newgame: roundfont: string
# % newgame: roundcoord: string
# % newgame: copycoord: string [ string ...]
# % newgame: overlays: string | [ string, ... ]
#
# If any of the mandatory entries are missing, delete the whole shebang
# and the main code will tell us that it can't make a game file.

sub fakeLayoutEntry($) {
	my ($title) = @_;
	open MAP, "<$opts{d}/$title-map.ps"
		or die "Unable to open $opts{d}/$title-map.ps: $!\n";
	while (<MAP>) {
		if ((my ($format) = /^\s*%\s+newgame:\s*nameformat:\s*(.*)/) == 1) {
			$layout{$title}{nameformat} = $format;
		}
		if ((my ($font) = /^\s*%\s+newgame:\s*namefont:\s*(.*)/) == 1) {
			$layout{$title}{namefont} = $font;
		}
		if ((my ($coord) = /^\s*%\s+newgame:\s*namecoord:\s*(.*)/) == 1) {
			$layout{$title}{namecoord} = $coord;
		}
		if ((my ($font) = /^\s*%\s+newgame:\s*roundfont:\s*(.*)/) == 1) {
			$layout{$title}{roundfont} = $font;
		}
		if ((my ($coord) = /^\s*%\s+newgame:\s*roundcoord:\s*(.*)/) == 1) {
			$layout{$title}{roundcoord} = $coord;
		}
		if ((my ($coords) = /^\s*%\s+newgame:\s*copycoord:\s*(.*)/) == 1) {
			$layout{$title}{copycoords} = []
				if !exists $layout{$title}{copycoords};
			push @{$layout{$title}{copycoords}}, split " ", $coords;
		}
		if ((my ($overs) = /^\s*%\s+newgame:\s*overlays:\s*(.*)/) == 1) {
			if ((my ($lhs, $rhs) = ($overs =~
						/(%?[\/\w]+)\s+=>\s+(.*)$/)) == 2) {
				if ((my ($list) = ($rhs =~ /^\[\s*(.*)\]\s*$/)) == 1) {
					$layout{$title}{overlays}{$lhs} =
						[ split /\s*,?\s+/, $list ];
				} else {
					$layout{$title}{overlays}{$lhs} = $rhs;
				}
			}
		}
	}
	close MAP;
	if (!exists($layout{$title})) {
		return;
	}
	if (!exists($layout{$title}{nameformat}) ||
		!exists($layout{$title}{namefont}) ||
		!exists($layout{$title}{namecoord}) ||
		!exists($layout{$title}{roundfont}) ||
		!exists($layout{$title}{roundcoord})) {
		delete($layout{$title});
		return;
	}
}

