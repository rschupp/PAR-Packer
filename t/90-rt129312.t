#!/usr/bin/perl -w

use strict;
use File::Spec::Functions;
use Data::Dumper;

use Test::More;
require "./t/utils.pl";

plan tests => 4;

my $hello = "hello, garbage\n";
my $exe = pp_ok(-e => "print qq[$hello]");
my $exe_size = -s $exe;

open my $fh, ">>:raw", $exe or die "can't append to $exe: $!";
my $garbage = "garbage\n" x 128; 
print $fh $garbage for 1..512;
close $fh;

is(-s $exe, $exe_size + length($garbage) * 512, "executable has 512 kB garbage appended");
my ($out, $err) = run_ok($exe);
is($out, $hello) or diag("stderr: $err");
