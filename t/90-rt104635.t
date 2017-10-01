#!/usr/bin/perl

use strict;
use warnings;

use File::Spec::Functions;
use Cwd;
use Archive::Zip qw( :ERROR_CODES );

use Test::More;
require "./t/utils.pl";

my @expected = qw( lib/Foo.pm lib/Foo/Bar.pm script/foo );
plan tests => @expected + 2;

chdir(catdir(qw( t 90-rt104635 ))) or die "can't chdir to t/90-rt104635: $!";

my $exe = pp_ok(-I => '.', catfile(qw( eg foo )));

my $zip = Archive::Zip->new();
$zip->read($exe) == AZ_OK or die "can't read $exe as a zip file";

ok($zip->memberNamed($_), "got member $_") for @expected;
ok(!$zip->memberNamed("lib/foo"), "no member lib/foo");
