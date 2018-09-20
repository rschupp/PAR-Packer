#!/usr/bin/perl -w

use strict;
use File::Spec::Functions;
use Data::Dumper;

use Test::More;
require "./t/utils.pl";

plan skip_all => "Tests only relevant on Windows" unless $^O eq 'MSWin32';
plan tests => 3;

my $exe = pp_ok(-e => 'use Data::Dumper; print Data::Dumper->new([\@ARGV])->Indent(1)->Useqq(1)->Dump');

# NOTE: pp_ok() sets $ENV{PAR_TMPDIR} as a side effect
$ENV{PAR_TMPDIR} = catdir($ENV{PAR_TMPDIR}, "t m p");   # path containing blanks
mkdir($ENV{PAR_TMPDIR}, 0755);

diag("running $exe with PAR_TMPDIR=$ENV{PAR_TMPDIR} ...");
my @argv = qw(foo bar quux);
my ($out) = run_ok($exe, @argv);
is( $out, Data::Dumper->new([\@argv])->Indent(1)->Useqq(1)->Dump);


