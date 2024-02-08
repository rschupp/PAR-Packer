#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
require "./t/utils.pl";

plan tests => 3;

# use an absolute pathname in case a test chdir()s
my $pp = catfile(getcwd(), qw( blib script pp ));

# runs 1 test
sub pp_p_ok
{
    $ENV{PAR_TMPDIR} ||= tempdir(TMPDIR => 1, CLEANUP => 1);
    my $par = catfile($ENV{PAR_TMPDIR},"my.par");
    unlink($par);

    die "system(LIST) with double quotes in LIST doesn't work on Windows: @_"
        if grep { /"/ } @_;
    # Note: The test harness runs tests 
    # with PERL5LIB prepended as if "-Mblib" was in effect
    system($^X, $pp, -p => -o => $par, @_);
    ok( $? == 0 && -f $par, qq[successfully packed "$par"] );

    return $par;
}

my $par = pp_p_ok(-I => "t/data/blib/lib", -I => "t/data/blib/arch", 
                  -e => "use XSFoo;");

my ($out, $err) = run_ok($^X, "-MPAR=$par", -e => "use XSFoo; XSFoo::hello()");
like($out, qr/greetings from XSFoo/, "output from XSFoo::hello matches");

