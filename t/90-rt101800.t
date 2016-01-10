#!/usr/bin/perl

use strict;
use warnings;
use Config;
use File::Spec::Functions;
use File::Temp qw( tempdir );
use File::Find;
use File::stat;

use PAR::SetupTemp;     # for $PAR::SetupTemp::Canary

use Test::More;
plan tests => 18;

$ENV{PAR_TMPDIR} = tempdir(TMPDIR => 1, CLEANUP => 1);

my $EXE = catfile($ENV{PAR_TMPDIR},"packed$Config{_exe}");
my $PP = catfile(qw( blib script pp ));
my $data = "AUTHORS";

# Note: there's nothing special about IPC::Open3 here - any module that
# (1) we know to be installed and (2) is not one of the "bundled" modules
# will do.
system $^X, $PP, 
    -o => $EXE, 
    -a => $data,
    -e => q[use IPC::Open3; print qq[PAR_TEMP=$ENV{PAR_TEMP}\n];];
ok( $? == 0 && -f $EXE, qq[successfully packed "$EXE"] ) 
    or die qq[couldn't pack "$EXE"];

my $t0 = time();
my $out = qx( $EXE );
ok( $? == 0, qq[successfully ran "$EXE"] )
    or die qq[running "$EXE" failed];
my ($par_temp) = $out =~ /^PAR_TEMP=(.*)$/m
    or die qq[can't find PAR_TEMP in "$out"];

my $canary = catfile($par_temp, $PAR::SetupTemp::Canary);
my $par_temp_inc = catdir($par_temp, "inc");
my $inc_data = catfile($par_temp_inc, $data);

ok(-e $canary, "canary file found in $par_temp");
ok(-d $par_temp_inc, "inc directory found in $par_temp");
ok(-e $inc_data, "data file found in $par_temp");
my $files_in_inc = find_all_files($par_temp_inc);
my @older_than_extraction = grep { stat($_)->mtime < $t0 } @$files_in_inc;
is("@older_than_extraction", "", "all files in $par_temp_inc are newer than extraction");

sleep(3);

my $t1 = time();
qx( $EXE );
ok( $? == 0, qq[successfully ran "$EXE" a second time] );
ok(-e $canary, "canary file found in $par_temp");
ok(-d $par_temp_inc, "inc directory found in $par_temp");
ok(-e $inc_data, "data file found in $par_temp");
my @newer_than_extraction = grep { stat($_)->mtime >= $t1 } @$files_in_inc;
is("@newer_than_extraction", "", "no files in $par_temp_inc have been updated for second run");

sleep(3);

# delete canary file, data file and every third file in $par_temp_inc
unlink($canary);
my $i = 0;
my @deleted = grep { $i++ % 3 == 0 } @$files_in_inc;
unlink($inc_data, @deleted);
ok(!-e $canary, "canary file removed");
ok(!-e $inc_data, "data file removed");

qx( $EXE );
ok( $? == 0, qq[successfully ran "$EXE" a third time] );
ok(-e $canary, "canary file found in $par_temp");
ok(-d $par_temp_inc, "inc directory found in $par_temp");
ok(-e $inc_data, "data file found in $par_temp");
my @not_restored = grep { !-e $_ } @deleted;
is("@not_restored", "", "all deleted files in $par_temp_inc haven been restored");

sub find_all_files
{
    my ($dir) = @_;
    my @found;
    find(sub { 
        push @found, $File::Find::name unless -d $_;
    }, $dir);
    return \@found;
}


