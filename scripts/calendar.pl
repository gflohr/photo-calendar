#! /usr/bin/env perl

use strict;

use POSIX qw(setlocale LC_ALL);

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
