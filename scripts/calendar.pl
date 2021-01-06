#! /usr/bin/env perl

use strict;

use POSIX qw(setlocale LC_ALL);
use Date::Holidays;
use Getopt::Long qw(GetOptions);
use File::Basename qw(basename dirname);

our $VERSION = '0.1.0';

sub display_version;
sub display_usage;
sub usage_error;

Getopt::Long::Configure('bundling');

my %options;

GetOptions(
	'h|help' => \$options{help},
	'V|version' => \$options{version},
) or usage_error;

display_usage if $options{help};
display_version if $options{version};

my @years;
my $locale = 'de_DE';

foreach my $year (@ARGV) {
	if ($year =~ /^[0-9]{4}$/) {
		push @years, $year;
	} elsif ($year =~ /^--locale=(.*)$/) {
		$locale = $1;
		$locale =~ s/^[ \t]+//;
		$locale =~ s/[ \t]+$//;
		if ($locale eq '') {
			die "$0: option '--locale' requires an argument";
		}
	} else {
		die "$0: invalid argument '$year'";
	}
}

if (!@years) {
	my @now = localtime;
	@years = $now[5];
}

if (!setlocale LC_ALL, $locale) {
	die "$0: The locale '$locale' is invalid or not installed";
}

sub display_version {
	my $program = basename __FILE__;

	print <<"EOF";
$program $VERSION
Copyright (C) 2020, Guido Flohr <guido.flohr\@cantanea.com>, all rights reserved.
EOF

	exit 0;
}

sub display_usage {
	my $program = basename __FILE__;

	print "Usage: ${program} [OPTION] [YEARS]...\n";

	print <<"EOF";
Generate directory and file structure for a qgoda photo calendar.

Mandatory arguments to long options are mandatory for short options too.
Similarly for optional arguments.

Informative output:
  -h, --help                  display this help page and exit
  -V, --version               output version information and exit

EOF

	exit 0;

}

sub usage_error {
	my ($message) = @_;

	my $program = basename __FILE__;

	if ($message) {
		$message =~ s/\s+$//;
		$message = "${program}: ${message}\n";
	} else {
			$message = '';
	}

	die $message . "Try '${program} --help' for more information!\n";
}