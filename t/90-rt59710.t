#!/usr/bin/perl -w

use strict;
use Config;
use File::Spec;
use FindBin;

use Test::More;
plan skip_all => "Unicode::UCD appeared first in perl 5.8.0"
    unless $] >= 5.008;
plan tests => 3; # FIXME

my $EXE = File::Spec->catfile( File::Spec->tmpdir,"rt59710$Config{_exe}");
my $PP = File::Spec->catdir( $FindBin::Bin, File::Spec->updir, qw( blib script pp ));

unlink $EXE;

system $PP, 
    -o => $EXE, 
    -e => 'use Unicode::UCD qw(charinfo); my $i = charinfo(0x42); print $i->{name};';
ok( $? == 0 && -f $EXE, "Created \"$EXE\"" ) 
        or die "Failed to create \"$EXE\"!\n";

my $name = qx( $EXE );
ok( $? == 0, "\"$EXE\" ran successfully");
is( $name, "LATIN CAPITAL LETTER B" );

# cleanup
unlink $EXE;
