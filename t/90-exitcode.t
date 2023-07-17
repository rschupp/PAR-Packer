#!/usr/bin/perl

use strict;
use warnings;
use File::Basename;

use Test::More;
require "./t/utils.pl";

my @scripts = ("exit(42);", "END { exit(42); }");
plan tests => 2* @scripts;

foreach my $script (@scripts) 
{
    my $exe = pp_ok( -e => $script);

    # obviously can't use run_ok() here
    run3([ $exe ], \undef);
    is($? >> 8, 42, qq[$exe exited with expected code]);
}

