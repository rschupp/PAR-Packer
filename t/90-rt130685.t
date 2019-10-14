#!/usr/bin/perl

use strict;
use warnings;

use Config;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

use Test::More;
require "./t/utils.pl";

# check that "pp -p" implies "pack no core modules"

plan tests => 2;

# Note: There may be a dual-life List::Util installed somewhere.
# Make sure pp uses the core one by explicitly searching the core
# installation directories first.
my $par = pp_ok(-I => $Config{archlibexp},
                -I => $Config{privlibexp},
                -p => -e => "use List::Util;");

my $zip = Archive::Zip->new();
$zip->read($par) == AZ_OK 
    or die qq[can't open par file "$par"];

ok(!$zip->memberNamed("lib/List/Util.pm"), "no member lib/List/Util.pm");
