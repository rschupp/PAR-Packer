#!/usr/bin/perl -w

use strict;
use Cwd;

use Test::More;
require "./t/utils.pl";

plan skip_all => "Tests only relevant on Windows" unless $^O eq 'MSWin32';

# FIXME system("\\\\?\\some-absolute-path") fails (returns -1 
# and $! == "No such file or directory") causing run3() to croak()
plan skip_all => "Test temporarily disabled";

plan tests => 3;

my $exe = pp_ok(-e => "print q[I'm OK]");

# run $exe with path prefixed by '\\?\' 
# cf. https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file
my ($out) = run_ok("\\\\?\\" . Cwd::abs_path($exe));
is($out, "I'm OK", qq[executable invoked with path prefixed by "\\\\?\\" ran OK]);
