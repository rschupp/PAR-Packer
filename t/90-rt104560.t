#!/usr/bin/perl -w

use strict;
use Config;
use File::Spec::Functions;
use File::Temp ();
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );;

use Test::More;

plan tests => 3;

$ENV{PAR_TMPDIR} = File::Temp::tempdir(TMPDIR => 1, CLEANUP => 1);

my $EXE = File::Spec->catfile($ENV{PAR_TMPDIR},"rt101800$Config{_exe}");
my $PP = File::Spec->catfile(qw( blib script pp ));

my $tmpfile1 = File::Spec->catfile($ENV{PAR_TMPDIR}, 'check1.txt');
my $tmpdir1  = File::Spec->catdir($ENV{PAR_TMPDIR}, 'checkdir1');
my $tmpfile2 = File::Spec->catfile($tmpdir1,  'check2.txt');

mkdir $tmpdir1;
foreach my $file ($tmpfile1, $tmpfile2) {
    open my $fh, '>', $file or die "Cannot open $file to write to";
    print $fh "this is $file\n\n";  #  contents don't matter for this test
    close $fh;
}

system $^X, $PP, 
    -o => $EXE, 
    -a => "$tmpfile1;check1.txt",
    -a => "$tmpdir1;checkdir1",
    -e => "print q[regression test for rt104560]";
ok( $? == 0 && -f $EXE, qq[successfully packed "$EXE"] ) 
    or die qq[couldn't pack "$EXE"];

my $zip = Archive::Zip->new();
$zip->read($EXE) == AZ_OK 
    or die qq[can't open zip file "$EXE"];
my $manifest = $zip->contents("MANIFEST")
    or die qq[can't read MANIFEST member];
# NOTE: Don't use like() below: early versions of Perl 5.8.x (x < 9)
# have a bug with the /m qualifier on compiled regexes that makes
# the test fail though $manifest is OK.
ok($manifest =~ m{^check1\.txt$}m,           "MANIFEST lists check1.txt");
ok($manifest =~ m{^checkdir1/check2\.txt$}m, "MANIFEST lists checkdir1/check2.txt");
