#!/usr/bin/perl

use strict;
use warnings;
use Config;
use File::Spec::Functions;
use Cwd qw( abs_path );
use File::Temp qw( tempdir );
use Archive::Zip qw( :ERROR_CODES );

use Test::More;
my @expected = qw( lib/Foo.pm lib/Foo/Bar.pm script/foo );

plan tests => @expected + 2;

$ENV{PAR_TMPDIR} = tempdir(TMPDIR => 1, CLEANUP => 1);

my $EXE = catfile($ENV{PAR_TMPDIR},"packed$Config{_exe}");
my $PP = abs_path(catfile(qw( blib script pp )));

chdir(catdir(qw( t 90-rt104635 ))) or die "can't chdir to t/90-rt104635: $!";

system $^X, $PP, 
    -o => $EXE, 
    catfile(qw( eg foo ));
ok( $? == 0 && -f $EXE, qq[successfully packed "$EXE"] ) 
    or die qq[couldn't pack "$EXE"];

my $zip = Archive::Zip->new();
$zip->read($EXE) == AZ_OK or die "can't read $EXE as a zip file";

ok($zip->memberNamed($_), "got member $_") for @expected;
ok(!$zip->memberNamed("lib/foo"), "no member lib/foo");
