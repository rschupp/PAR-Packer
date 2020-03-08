#!/usr/bin/perl

use strict;
use warnings;

use Cwd;
use File::Spec::Functions;

use Test::More;
require "./t/utils.pl";

plan tests => 4;

my $exe = pp_ok(-I => "t", -e => <<'...');
use Cwd;
use Data::Dumper;
use Myfile;
my $data = 
{ 
    par_temp    => Cwd::realpath($ENV{PAR_TEMP}), 
    from_file   => Myfile::from_file(), 
    from_caller => Myfile::from_caller(), 
};
print Data::Dumper->new([$data], ['data'])->Useqq(1)->Dump;
...

my ($out, $err) = run_ok($exe);
diag("out = <<<$out>>>");  # FIXME
diag("err = <<<$err>>>");  # FIXME

our $data;
eval($out);

my $exp_file = catfile($data->{par_temp}, qw( inc lib Myfile.pm ));
is($exp_file, $data->{from_file},   "source path from __FILE__");
is($exp_file, $data->{from_caller}, "source path from (caller)[1]");
