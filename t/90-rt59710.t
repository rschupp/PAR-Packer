#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
require "./t/utils.pl";

# Unicode::UCD appeared first in perl 5.8.0
plan skip_all => "Unicode::UCD not installed"
    unless eval "require Unicode::UCD; 1";
plan tests => 3;

my $exe = pp_ok(-e => 'use Unicode::UCD qw(charinfo); my $i = charinfo(0x42); print $i->{name};');

my ($out) = run_ok($exe);
is( $out, "LATIN CAPITAL LETTER B", "name of U+0042" );

