#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
require "./t/utils.pl";

plan tests => 3;

my $exe = pp_ok(-e => 'for (my $i = 0; $i < @ARGV; $i++) { printf qq[%d#%s\n], $i, $ARGV[$i]; }');
my ($out) = run_ok($exe, '*');
is($out, "0#*\n", "no globbing of arguments");
