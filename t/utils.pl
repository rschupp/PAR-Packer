#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Config;
use File::Spec::Functions;
use File::Temp qw( tempdir );
use Cwd;
use IPC::Run3;

# use an absolute pathname in case a test chdir()s
my $pp = catfile(getcwd(), qw( blib script pp ));

# runs 1 test
sub pp_ok
{
    $ENV{PAR_TMPDIR} ||= tempdir(TMPDIR => 1, CLEANUP => 1);
    my $exe = catfile($ENV{PAR_TMPDIR},"packed$Config{_exe}");
    unlink($exe);

    die "system(LIST) with double quotes in LIST doesn't work on Windows: @_"
        if grep { /"/ } @_;
    system($^X, $pp, -o => $exe, @_);
    # Note: -x is unreliable on Windows
    ok( $? == 0 && -f $exe, qq[successfully packed "$exe"] );

    return $exe;
}

# runs 1 test
sub run_ok
{
    my @cmd = @_;

    my ($out, $err);
    run3(\@cmd, \undef, \$out, \$err);
    is( $?, 0, qq[successfully ran "@cmd"] );

    return ($out, $err);
}


1;
