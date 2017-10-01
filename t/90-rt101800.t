#!/usr/bin/perl

use strict;
use warnings;
use Config;
use File::Spec::Functions;
use File::Find;
use File::stat;

use PAR::SetupTemp;     # for $PAR::SetupTemp::Canary

use Test::More;
require "./t/utils.pl";

if (eval { require Archive::Unzip::Burst; 1; })
{
    plan skip_all => "Archive::Unzip::Burst detected";
}
else
{
    plan tests => 18;
}

my $data = "AUTHORS";

# Note: there's nothing special about IPC::Open3 here - any module that
# (1) we know to be installed and (2) is not one of the "bundled" modules
# will do.
my $exe = pp_ok(-a => $data,
                -e => q[use IPC::Open3; print qq[PAR_TEMP=$ENV{PAR_TEMP}\n];]);

my $t0 = time();
my ($out) = run_ok($exe);
my ($par_temp) = $out =~ /^PAR_TEMP=(.*)$/m
    or die qq[can't find PAR_TEMP in "$out"];
diag("PAR_TEMP = $par_temp");

my $canary = catfile($par_temp, $PAR::SetupTemp::Canary);
my $par_temp_inc = catdir($par_temp, "inc");
my $inc_data = catfile($par_temp_inc, $data);

ok(-e $canary, 'canary file found in $PAR_TEMP');
ok(-d $par_temp_inc, 'inc directory found in $PAR_TEMP');
ok(-e $inc_data, 'data file found in $PAR_TEMP');
my $files_in_inc = find_all_files($par_temp_inc);
my @older_than_extraction = grep { stat($_)->mtime < $t0 } @$files_in_inc;
unless (is(scalar(@older_than_extraction), 0, 
           'all files in $PAR_TEMP/inc are newer than extraction')) {
    diag("time of extraction: $t0");
    diag(sprintf("mtime %s: %d", $_, stat($_)->mtime)) foreach @older_than_extraction;
}

sleep(3);

my $t1 = time();
diag("running $exe a second time");
run_ok($exe);
ok(-e $canary, 'canary file found in $PAR_TEMP');
ok(-d $par_temp_inc, 'inc directory found in $PAR_TEMP');
ok(-e $inc_data, 'data file found in $PAR_TEMP');
my @newer_than_extraction = grep { stat($_)->mtime >= $t1 } @$files_in_inc;
unless (is(scalar(@newer_than_extraction), 0,
           'no files in $PAR_TEMP/inc have been updated for second run')) {
    diag("time of second run: $t1");
    diag(sprintf("mtime %s: %d", $_, stat($_)->mtime)) foreach @newer_than_extraction;
}

sleep(3);

# delete canary file, data file and every third file in $par_temp_inc
unlink($canary);
my $i = 0;
my @deleted = grep { $i++ % 3 == 0 } @$files_in_inc;
unlink($inc_data, @deleted);
ok(!-e $canary, "canary file removed");
ok(!-e $inc_data, "data file removed");

diag("running $exe a third time");
run_ok($exe);
ok(-e $canary, 'canary file found in $PAR_TEMP');
ok(-d $par_temp_inc, 'inc directory found in $PAR_TEMP');
ok(-e $inc_data, 'data file found in $PAR_TEMP');
my @not_restored = grep { !-e $_ } @deleted;
unless (is(scalar(@not_restored), 0, 
           'all deleted files in $PAR_TEMP/inc haven been restored')) {
    diag("not restored: $_") foreach @not_restored;
}

sub find_all_files
{
    my ($dir) = @_;
    my @found;
    find(sub { 
        push @found, $File::Find::name unless -d $_;
    }, $dir);
    return \@found;
}


