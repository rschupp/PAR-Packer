#!/usr/bin/perl

# pp_minus_o_foo_foo_dot_pl_bar_dot_pl

use strict;
use warnings;

use Test::More;
require "./t/utils.pl";

my %files = create_temp_files(
    "foo.pl" => 'print "hello from foo";',
    "bar.pl" => 'print "hello from bar";',
);

my $out;

# FIXME need pp_ok where we can override the (basename) of the packed exe
# (file should reside in a temp directory)
my $foo_exe = pp_ok(
    -o "foo$Config{_exe}", 
    @files{qw( foo.pl bar.pl )});

($out) = run_ok($foo_exe);
is(out, "hello from foo");

use File::Copy 'cp';    # FIXME
my $bar_exe = catfile(dirname($foo_exe), "bar$Config{_exe}");
cp($foo_exe, $bar_exe) or die "can't copy $foo_exe to $bar_exe: $!";

($out) = run_ok($bar_exe);
is(out, "hello from bar");