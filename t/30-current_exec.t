#!/usr/bin/perl

use strict;
use warnings;
use Config;
use File::Spec::Functions;
use File::Path;
use File::Basename;
use FindBin;

use Test::More;
require "./t/utils.pl";

plan skip_all => "Fails if run in a path that contains spaces" 
    if $FindBin::Bin =~ / /;
plan tests => 5;

my $exe = pp_ok( catfile(qw(t test-proc)) );

$ENV{PAR_GLOBAL_TMPDIR} = $ENV{PAR_TMPDIR};     # set by pp_ok

my ($out1) = run_ok( $exe );
ok( $out1 =~ /PAR_TEMP = \Q$ENV{PAR_TMPDIR}\E/, "Respected PAR_GLOBAL_TMPDIR" );

my( $file, $path ) = fileparse( $exe );
my ($out2) = do { 
    local $ENV{PATH} = join($Config{path_sep} || ':', $path, File::Spec->path());
    run_ok($file);
};

is( $out1, $out2, "Found the same file via PATH and full path" );
