#!/usr/bin/perl -w
# $Id$
use strict;
use Config;
use File::Spec;
use File::Path;
use File::Basename;
use File::Temp ();
use FindBin;

use Test::More;
plan skip_all => "Fails if run in a path that contains spaces" 
    if $FindBin::Bin =~ / /;
plan tests => 3;

$ENV{PAR_TMPDIR} = File::Temp::tempdir(TMPDIR => 1, CLEANUP => 1);

####
my $EXEC = File::Spec->catfile( $FindBin::Bin, "test-10$Config{_exe}" );
my $TEMP = join '-', $FindBin::Bin, "tmp";
my $SCRIPT = File::Spec->catdir( $FindBin::Bin, File::Spec->updir, "blib", "script" );
my $PP = File::Spec->catfile( $SCRIPT, 'pp' );
my $blib_lib = File::Spec->catdir("blib", "lib");

my $sep = $Config{path_sep};
$sep = ':' if not defined $sep;
$blib_lib .= $sep if $ENV{PERL5LIB};
$ENV{PERL5LIB} = defined($ENV{PERL5LIB}) ? $blib_lib . $ENV{PERL5LIB} : $blib_lib;



####
unlink $EXEC       if -f $EXEC;
rmtree( [$TEMP] )  if -d $TEMP;
mkpath( [$TEMP], 0, 0700 );

####
diag( "Please wait" );
my $test_proc = File::Spec->catfile('t', 'test-proc');
system( $^X, $PP, '-o', $EXEC, $test_proc );

ok( (-f $EXEC), "Created \"$EXEC\"" ) 
        or die "Failed to create \"$EXEC\"!\n";

####
$ENV{PAR_GLOBAL_TMPDIR} = $TEMP;
my $out_full = qx($EXEC);

ok( ($out_full =~ /PAR_TEMP = \Q$TEMP\E/), "Respected PAR_GLOBAL_TMPDIR" );

my( $file, $path ) = fileparse( $EXEC );

my $out_path = do { local $ENV{PATH} = join($sep, $path, File::Spec->path()); qx($file); };

is( $out_path, $out_full, "Found the same file via PATH and full path" );

# warn qq(out_full="$out_full"\n out_path="$out_path"\n);;


#### Clean up
unlink $EXEC;
rmtree( [$TEMP] );
#mkpath( [$TEMP], 0, 0700 );


1;

__END__

$Log$


