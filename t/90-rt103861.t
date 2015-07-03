#!/usr/bin/perl

use strict;
use warnings;
use Config;
use File::Spec::Functions;
use File::Temp qw( tempdir );

use Test::More;
plan tests => 3;

$ENV{PAR_TMPDIR} = tempdir(TMPDIR => 1, CLEANUP => 1);

my $EXE = catfile($ENV{PAR_TMPDIR},"packed$Config{_exe}");
my $PP = catfile(qw( blib script pp ));

system $^X, $PP, 
    -o => $EXE, 
    -e => q[use lib 'foo'; use lib 'bar'; print qq[$_\n] foreach @INC];
ok( $? == 0 && -f $EXE, qq[successfully packed "$EXE"] ) 
    or die qq[couldn't pack "$EXE"];

my $out = qx( $EXE );
ok( $? == 0, qq[successfully ran "$EXE"] );
like( $out, qr/^bar\nfoo\n/, q["foo" and "bar" added to @INC] );

