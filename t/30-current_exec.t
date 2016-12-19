#!/usr/bin/perl

use strict;
use warnings;
use Config;
use File::Spec::Functions;
use File::Path;
use File::Basename;
use File::Temp ();
use FindBin;

use Test::More;
plan skip_all => "Fails if run in a path that contains spaces" 
    if $FindBin::Bin =~ / /;
plan tests => 3;

$ENV{PAR_TMPDIR} = File::Temp::tempdir(TMPDIR => 1, CLEANUP => 1);

my $EXE = catfile($ENV{PAR_TMPDIR}, "current_exec$Config{_exe}");

####
diag( "Please wait" );
my $test_proc = catfile(qw(t test-proc));
system $^X, catfile(qw( blib script pp )),
       '-o', $EXE, $test_proc;

ok( (-f $EXE), "Created \"$EXE\"" ) 
        or die "Failed to create \"$EXE\"!\n";

####
$ENV{PAR_GLOBAL_TMPDIR} = $ENV{PAR_TMPDIR};
my $out_full = qx($EXE);

ok( ($out_full =~ /PAR_TEMP = \Q$ENV{PAR_TMPDIR}\E/), "Respected PAR_GLOBAL_TMPDIR" );

my( $file, $path ) = fileparse( $EXE );

my $out_path = do { local $ENV{PATH} = join($Config{path_sep} || ':', $path, File::Spec->path()); qx($file); };

is( $out_path, $out_full, "Found the same file via PATH and full path" );


1;
