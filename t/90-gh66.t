#!/usr/bin/perl

use strict;
use warnings;
use File::Basename;

use Test::More;
require "./t/utils.pl";

plan tests => 10;

my ($exe, $out, %val);
my $script = 'print qq[PAR_TEMP=$ENV{PAR_TEMP}\nPAR_CLEAN=$ENV{PAR_CLEAN}\n]';

$exe = pp_ok( -e => $script );
($out) = run_ok($exe);
#diag($out);
%val = $out =~ /^(PAR_\w+)=(.*)$/gm;
like( basename($val{PAR_TEMP}), qr/^cache-/, "$val{PAR_TEMP} is a persistent cache directory" );
ok(!$val{PAR_CLEAN}, "won't clean");
ok(-d $val{PAR_TEMP}, "cache directory still exists");

$exe = pp_ok( "--clean", -e => $script );
($out) = run_ok($exe);
#diag($out);
%val = $out =~ /^(PAR_\w+)=(.*)$/gm;
like( basename($val{PAR_TEMP}), qr/^temp-/, "$val{PAR_TEMP} is an ephemeral cache directory" );
ok($val{PAR_CLEAN}, "will clean");
ok(!-e $val{PAR_TEMP}, "cache directory has been removed");

