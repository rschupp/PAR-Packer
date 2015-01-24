#!/usr/bin/perl -w

use strict;
use Config;
use File::Spec::Functions;
use File::Temp ();

use Test::More;
# Unicode::UCD appeared first in perl 5.8.0
plan skip_all => "Unicode::UCD not installed"
    unless eval "require Unicode::UCD; 1";

plan tests => 3; # FIXME

$ENV{PAR_TMPDIR} = File::Temp::tempdir(TMPDIR => 1, CLEANUP => 1);

my $EXE = File::Spec->catfile($ENV{PAR_TMPDIR},"rt59710$Config{_exe}");
my $PP = File::Spec->catfile(qw( blib script pp ));

system $^X, $PP, 
    -o => $EXE, 
    -e => 'use Unicode::UCD qw(charinfo); my $i = charinfo(0x42); print $i->{name};';
ok( $? == 0 && -f $EXE, qq[successfully packed "$EXE"] ) 
    or die qq[couldn't pack "$EXE"];

my $name = qx( $EXE );
ok( $? == 0, qq[successfully ran "$EXE"]);
is( $name, "LATIN CAPITAL LETTER B", "name of U+0042" );

