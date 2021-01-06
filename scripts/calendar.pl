#! /usr/bin/env perl

use strict;

use POSIX qw(setlocale LC_ALL);
use Date::Holidays;
use Getopt::Long qw(GetOptions);
use File::Basename qw(basename dirname);
use File::Path qw(remove_tree make_path);
use File::Find qw(find);
use YAML::XS;

our $VERSION = '0.1.0';

sub display_version;
sub display_usage;
sub usage_error;
sub create_year;
sub create_month;
sub create_day;
sub cleanup;
sub docs_dir;
sub images_dir;
sub is_leap_year;
sub write_file;
sub convert_locale;

Getopt::Long::Configure('bundling');

my %options = (
	country => 'de',
	state => 'nrw',
	locale => 'de_DE',
);

my @mdays = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);

GetOptions(
	'c|country=s' => \$options{country},
	's|state=s' => \$options{state},
	'r|region=s' => \$options{region},
	'h|help' => \$options{help},
	'V|version' => \$options{version},
) or usage_error;

display_usage if $options{help};
display_version if $options{version};

my @years;

foreach my $year (@ARGV) {
	if ($year =~ /^[0-9]{4}$/) {
		push @years, $year;
	} else {
		die "$0: invalid year '$year'";
	}
}

if (!@years) {
	my @now = localtime;
	@years = 1900 + $now[5];
}

if (!setlocale LC_ALL, $options{locale}) {
	die "$0: The locale '$options{locale}' is invalid or not installed";
}

$options{country} = uc $options{country};

my $dh = Date::Holidays->new(
	countrycode => $options{country}
);

usage_error "countrycode '$options{country}' is invalid or the module"
	. " Date::Holidays::$options{country} is not installed"
	if !$dh;

cleanup;
foreach my $year (@years) {
	create_year $dh, $year;
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

Locale:
  -c, --country=COUNTRY       ISO 639-1 country code (default: de)
  -s, --state=STATE           Optional state (default: nw)
  -r, --region=REGION         Region code

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

sub create_year {
	my ($dh, $year) = @_;

	my $images_dir = images_dir;
	my $year_dir = "$images_dir/$year";

	make_path $year_dir;

	my $docs_dir = docs_dir;

	make_path $docs_dir;

	my $doc_path = "$docs_dir/$year.md";

	my %meta;
	$meta{year} = $year;
	$meta{mdays} = [@mdays];
	++$meta{mdays}[1] if is_leap_year $year;
	$meta{lang} = convert_locale $options{locale};

	foreach my $month (0 .. 1) {

	}

	my $content = Dump \%meta;
	write_file $doc_path, $content . "---\n";
}

sub docs_dir {
	my $program_dir = dirname __FILE__;

	return $program_dir . '/../calendar';
}

sub images_dir {
	my $program_dir = dirname __FILE__;

	return $program_dir . '/../images';
}

sub cleanup {
	my $docs_dir = docs_dir;
	if (-e $docs_dir) {
		my $deleted = remove_tree $docs_dir, { safe => 1 };
		if (!$deleted) {
			die "error deleting old docs_dir: $!";
		}
	}

	my $wanted = sub {
		return if !-d $_;

		rmdir $_;
	};

	my $images_dir = images_dir;

	find {
		wanted => $wanted,
		bydepth => 1,
	}, $images_dir;

	rmdir $images_dir;

	return 1;
}

sub is_leap_year
{
	my ($year) = @_;

	return if $year % 4;
	return 1 if $year % 100;
	return if $year % 400;
	return 1;
}

sub write_file {
	my ($path, $content) = @_;

	open my $fh, '>', $path
		or die "cannot open '$path' for writing: $!";
	$fh->print($content)
		or die "cannot write to '$path': $!";
	$fh->close
		or die "cannot close '$path': $!";
	
	return 1;
}

sub convert_locale {
	my ($locale) = @_;

	$locale =~ s/[_@]/-/g;

	return lc $locale;
}