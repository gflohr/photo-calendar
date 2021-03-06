#! /usr/bin/env perl

use strict;

use POSIX qw(setlocale LC_ALL mktime);
use Date::Holidays;
use Getopt::Long qw(GetOptions);
use File::Basename qw(basename dirname);
use File::Path qw(remove_tree make_path);
use File::Find qw(find);
use YAML::XS;
use I18N::Langinfo;

our $VERSION = '0.1.0';

sub display_version;
sub display_usage;
sub usage_error;
sub create_start;
sub create_year;
sub create_month;
sub create_day;
sub cleanup;
sub docs_dir;
sub images_dir;
sub is_leap_year;
sub write_markdown;
sub write_file;
sub convert_locale;
sub month_start;

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
create_start @years;
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

sub create_day {
	my ($dh, $year, $month, $day) = @_;
}

sub create_month {
	my ($dh, $year, $month) = @_;

	my $zmonth = sprintf '%02u', $month + 1;

	my $images_dir = images_dir;
	my $zmonth_dir = "$images_dir/$year/$zmonth";

	make_path $zmonth_dir;

	my $docs_dir = docs_dir;
	my $year_dir = "$docs_dir/$year";

	make_path $year_dir;

	my $doc_path = "$year_dir/$zmonth.md";

	my %meta;
	$meta{year} = $year;
	$meta{month} = $month;
	$meta{zmonth} = $zmonth;
	$meta{name} = $meta{title} = "$year/$zmonth";
	$meta{type} = 'month';
	$meta{numdays} = $mdays[$month];
	++$meta{num_days} if $month == 2 && is_leap_year $year;
	$meta{month_start} = month_start $year, $month;
	$meta{lang} = convert_locale $options{locale};

	foreach my $day (1 .. $meta{num_days}) {
		create_day $dh, $year, $month, $day;
	}

	write_markdown $doc_path, \%meta;
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
	$meta{year} = $meta{title} = $meta{name} = $year;
	$meta{type} = 'year';
	$meta{mdays} = [@mdays];
	++$meta{mdays}[1] if is_leap_year $year;
	$meta{lang} = convert_locale $options{locale};

	foreach my $month (0 .. 11) {
		create_month $dh, $year, $month;
	}

	write_markdown $doc_path, \%meta;
}

sub create_start {
	my (@years) = @_;

	my %meta = (
		name => 'start',
		title => 'Photo Calendar',
		location => '/index.html',
	);

	my $content = <<"EOF";
[% USE q = Qgoda %]
<h1>[% asset.title %]</h1>
EOF

	foreach my $year (@years) {
		$content .= <<"EOF";
* [% q.anchor(name = $year) %]
EOF
	}

	my $docs_dir = docs_dir;
	mkdir $docs_dir;
	my $doc_path = $docs_dir . '/index.md';
	write_markdown $doc_path, \%meta, $content;
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

sub write_markdown {
	my ($path, $meta, $content) = @_;

	$content = '' if !defined $content;

	my $header = Dump $meta;
	write_file $path, "$header---\n$content";
}

sub month_start {
	my ($year, $month) = @_;

	my @then = gmtime mktime 0, 0, 12, 1, $month, $year - 1900;
	my $wday = $then[6];

	my $start = -$wday + 2;

	return $start > 1 ? -5 : $start;
}