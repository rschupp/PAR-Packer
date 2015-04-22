#!/usr/bin/perl

use strict;
use warnings;
use Config;
use File::Spec::Functions;
use File::Temp ();

use Test::More;
plan tests => 3; # FIXME

$ENV{PAR_TMPDIR} = File::Temp::tempdir(TMPDIR => 1, CLEANUP => 1);

my $EXE = File::Spec->catfile($ENV{PAR_TMPDIR},"rt103861$Config{_exe}");
my $PP = File::Spec->catfile(qw( blib script pp ));

system $^X, $PP, 
    -o => $EXE, 
    -e => <<'...';
  use lib "foo"; 
  use lib "bar"; 
  print "$_\n" foreach @INC;
...
ok( $? == 0 && -f $EXE, qq[successfully packed "$EXE"] ) 
    or die qq[couldn't pack "$EXE"];

my $out = qx( $EXE );
ok( $? == 0, qq[successfully ran "$EXE"] );
like( $out, qr/^bar\nfoo\n/, q["foo" and "bar" added to @INC] );

