#!/usr/bin/perl

use strict;
use warnings;
use Config;
use File::Spec::Functions;
use Cwd qw( abs_path );
use File::Temp qw( tempdir );
use Archive::Zip qw( :ERROR_CODES );

use Test::More;
my @expected = qw(
    lib/Double/Colon.pm
    lib/Double/Colon/Barnie.pm
    lib/Double/Colon/Foo/Bar/Quux.pm
    lib/Double/Colon/Fred.pm
);

plan tests => @expected + 1;

$ENV{PAR_TMPDIR} = tempdir(TMPDIR => 1, CLEANUP => 1);

my $EXE = catfile($ENV{PAR_TMPDIR},"packed$Config{_exe}");
my $PP = abs_path(catfile(qw( blib script pp )));

system $^X, $PP, 
    -o => $EXE, 
    -I => "t",
    -M => "Double::Colon::",
    -e => "print 'test -M with trailing ::'";
ok( $? == 0 && -f $EXE, qq[successfully packed "$EXE"] ) 
    or die qq[couldn't pack "$EXE"];

my $zip = Archive::Zip->new();
$zip->read($EXE) == AZ_OK or die "can't read $EXE as a zip file";

ok($zip->memberNamed($_), "got member $_") for @expected;
