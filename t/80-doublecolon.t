#!/usr/bin/perl

use strict;
use warnings;
use Config;
use File::Spec::Functions;
use Cwd qw( abs_path );
use File::Temp qw( tempdir );
use Archive::Zip qw( :ERROR_CODES );

use Test::More;
my %expected = (
    "Double::Colon" => [qw(
            lib/Double/Colon.pm
        )],
    "Double::Colon::" => [qw(
            lib/Double/Colon.pm
            lib/Double/Colon/Barnie.pm
            lib/Double/Colon/Foo/Bar/Quux.pm
            lib/Double/Colon/Fred.pm
        )],
    "Double::Colon::*" => [qw(
            lib/Double/Colon/Barnie.pm
            lib/Double/Colon/Fred.pm
        )],
    "Double::Colon::**" => [qw(
            lib/Double/Colon/Barnie.pm
            lib/Double/Colon/Foo/Bar/Quux.pm
            lib/Double/Colon/Fred.pm
        )],
);

plan tests => 2 * (keys %expected);

$ENV{PAR_TMPDIR} = tempdir(TMPDIR => 1, CLEANUP => 1);

my $EXE = catfile($ENV{PAR_TMPDIR},"packed$Config{_exe}");
my $PP = abs_path(catfile(qw( blib script pp )));

while (my ($M, $exp) = each %expected) {
    system $^X, $PP, -o => $EXE, -I => "t", -M => $M,
                     -e => q[print qq[testing 'pp -M Foo::\n]];
    ok( $? == 0 && -f $EXE, qq[successfully packed "$EXE"] ) 
        or die qq[couldn't pack "$EXE"];

    my $zip = Archive::Zip->new();
    $zip->read($EXE) == AZ_OK or die "can't read $EXE as a zip file";

    my @double_colons = sort grep { m{Double/Colon} } 
                                  map { $_->fileName() }
                                      grep { !$_->isDirectory() } 
                                           $zip->members();
    is("@double_colons", "@$exp", "modules for '-M$M'");
}
