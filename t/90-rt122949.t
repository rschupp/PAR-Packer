#!/usr/bin/perl -w

use strict;
use Data::Dumper;

use Test::More;
require "t/utils.pl";

my @tests = (
  [ qw[foo bar quux] ],
  [ qq[foo bar quux] ],
  [ qq[foo\\] ],
  [ qq[foo\\\\] ],
  [ qq[foo\\\\\\] ],
  [ qq[foo\\"bar] ],
  [ qq[foo\\\\"bar] ],
  [ qq[foo\\\\\\"bar] ],

  # patterns stolen from Win32::ShellQuote, test t/quoting.t
  [ qq[a] ],
  [ qq[a b] ],
  [ qq["a b"] ],
  [ qq["a" b] ],
  [ qq["a" "b"] ],
  [ qq['a'] ],
  [ qq["a] ],
  [ qq["a b] ],
  [ qq['a] ],
  [ qq['a b] ],
  [ qq['a b"] ],
  [ qq[\\a] ],
  [ qq[\\"a] ],
  [ qq[\\ a] ],
  [ qq[\\ "' a] ],
  [ qq[\\ "' a], qq[>\\] ],
  [ qq[%a%] ],
  [ qq[%a b] ],
  [ qq[\\%a b] ],
  [ qq[ & help & ] ],
  [ qq[ > out] ],
  [ qq[ | welp] ],
  [ qq[" | welp"] ],
  [ qq[\\" | welp] ],
  [ qq[] ],
  [ qq[print "foo'o", ' bar"ar'] ],
  [ qq[\$PATH = 'foo'; print \$PATH] ],
  [ qq[print 'foo'] ],
  [ qq[print " \\" "] ],
  [ qq[print " < \\" "] ],
  [ qq[print " \\" < "] ],
  [ qq[print " < \\"\\" < \\" < \\" < "] ],
  [ qq[print " < \\" | \\" < | \\" < \\" < "] ],
  [ qq[print q[ &<>^|()\@ ! ]] ],
  [ qq[print q[ &<>^|\@()!"&<>^|\@()! ]] ],
  [ qq[print q[ "&<>^|\@() !"&<>^|\@() !" ]] ],
  [ qq[print q[ "C:\\TEST A\\" ]] ],
  [ qq[print q[ "C:\\TEST %&^ A\\" ]] ],
  [ qq[\n] ],
  [ qq[a\nb] ],
  [ qq[a\rb] ],
  [ qq[a\nb > welp] ],
  [ qq[a > welp\n219] ],
  [ qq[a"b\nc] ],
  [ qq[a\fb] ],
  [ qq[a\x0bb] ],
  [ qq[a\x{85}b] ],
);

plan skip_all => "Tests only relevant on Windows" unless $^O eq 'MSWin32';
plan tests => 2 * @tests + 1;

my $exe = pp_ok(-e => 'use Data::Dumper; print Data::Dumper->new([\\@ARGV])->Indent(1)->Useqq(1)->Dump');

foreach my $t (@tests)
{
    my ($out) = run_ok($exe, @$t);
    is( $out, Data::Dumper->new([$t])->Indent(1)->Useqq(1)->Dump);
}


