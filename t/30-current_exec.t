#!/usr/bin/perl -w
# $Id$
use strict;
use Config;
use File::Spec;
use File::Path;
use File::Basename;
use FindBin;

use Test::More ( tests => 4 );

my $has_inline_c = eval "use Inline; 1;";
# warn $@ if $@;

####
my $EXEC = File::Spec->catfile( $FindBin::Bin, "test-10.exec" );
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
system( $PP, '-o', $EXEC, $test_proc );

ok( (-f $EXEC), "Created \"$EXEC\"" ) 
        or die "Failed to create \"$EXEC\"!\n";

####
$ENV{PAR_GLOBAL_TMPDIR} = $TEMP;
my $out_full = qx($EXEC);

ok( ($out_full =~ /PAR_TEMP = \Q$TEMP\E/), "Respected PAR_GLOBAL_TMPDIR" );

my( $file, $path ) = fileparse( $EXEC );

my $out_path = do { local $ENV{PATH} = $path; qx($file); };

is( $out_path, $out_full, "Found the same file via PATH and full path" );

# warn qq(out_full="$out_full"\n out_path="$out_path"\n);;

####
SKIP: {
    skip "Inline::C not installed; Can't verify with execvp", 1
            unless $has_inline_c;
    skip "Can't get running executable that isn't in PATH on $^O", 1
            unless $^O =~ /linux/i or 
		   ( $^O =~ /freebsd/i and -l "/proc/$$/file" );

    diag( "Please wait" );
    Inline->bind( C => <<'C' );
#include <unistd.h>
#include <stdio.h>

        void exec_prog( char *full_path, char *exec ) 
        {
            char * args[]={NULL, NULL};
            args[0] = exec;
            execvp( full_path, args );
            perror( "execvp failed" );
            exit(3);
        }
C


    my $pid = open PROG, "-|";
    die "Can't fork: $!" unless defined $pid;
    unless( $pid ) {        # child
        $ENV{PAR_GLOBAL_TMPDIR} = $TEMP;
        # warn "EXEC=$EXEC file=$file" ;
		$ENV{PATH} = $path;
        exec_prog( $EXEC, $file );
    }
    my $exec_full = join '', <PROG>;

    is( $exec_full, $out_path, "Found the same file via execvp and PATH" );
}

#### Clean up
unlink $EXEC;
rmtree( [$TEMP] );
#mkpath( [$TEMP], 0, 0700 );


1;

__END__

$Log$


