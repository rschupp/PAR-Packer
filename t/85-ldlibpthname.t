#!/usr/bin/perl -w

use strict;
use Config;
use Data::Dumper;

use Test::More;
require "./t/utils.pl";

my $ldlibpthname = $^O eq 'MSWin32' ? "PATH" : $Config{ldlibpthname};

plan skip_all => "\$Config{ldlibpthname} is not available for your OS ($^O)" unless $ldlibpthname;
plan tests => 3;

my $exe = pp_ok(-e => <<"...");
    use Data::Dumper; 
    my \$data = { 
        par_temp => \$ENV{PAR_TEMP}, 
        ldlibpth => \$ENV{$ldlibpthname},
    };
    print Data::Dumper->new([\$data], ['data'])->Indent(1)->Useqq(1)->Dump();
...

my ($out) = run_ok($exe);
our $data;
eval $out;
ok($data->{ldlibpth} =~ /^\Q$data->{par_temp}\E($|\Q$Config{path_sep}\E)/,
    "PAR_TEMP is first item in $ldlibpthname as seen by packed executable")
    or diag($out);


