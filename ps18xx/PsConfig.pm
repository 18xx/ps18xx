package PsConfig;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw( getconfig %config );
our $VERSION = 1.00;

sub getconfig($) {
	my ($program) = @_;

	open CONF, "<config" or return;
	while (<CONF>) {
		s/^\s*#.*$//;
		s/\s*$//;
		next if /^$/;
		die "Parse error in config\n" unless
			(my ($prog, $key, $val) = /(\w+)\s*:\s*(\w+)\s*(.*)/) == 3;
		next unless $prog eq $program;
		$config{$key} = $val;
	}
	close CONF;
}

1;
