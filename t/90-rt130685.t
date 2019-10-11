#!/usr/bin/perl

use strict;
use warnings;

use Config;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

use Test::More;
require "./t/utils.pl";

# check that "pp -p" implies "pack no core modules"

plan tests => 2;

my $par = pp_ok(-p => -e => "use List::Util;");

my $zip = Archive::Zip->new();
$zip->read($par) == AZ_OK 
    or die qq[can't open par file "$par"];

ok(!$zip->memberNamed("lib/List/Util.pm"), "no member lib/List/Util.pm");
