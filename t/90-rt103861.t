#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
require "./t/utils.pl";

plan tests => 3;

my $exe = pp_ok(-e => q[use lib 'foo'; use lib 'bar'; print qq[$_\n] foreach @INC]);

my ($out) = run_ok($exe);
like( $out, qr/^bar\nfoo\n/, q["foo" and "bar" added to @INC] );

