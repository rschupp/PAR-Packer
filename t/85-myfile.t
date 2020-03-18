#!/usr/bin/perl

use strict;
use warnings;

use Cwd;
use File::Spec::Functions;

use Test::More;
require "./t/utils.pl";

plan tests => 6;

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

our $data;
eval($out);

my $exp_file = catfile($data->{par_temp}, qw( inc lib Myfile.pm ));
$exp_file =~ s{\\}{/}g if $^O eq 'MSWin32';

is($data->{from_file}, $exp_file, "expected source path from __FILE__");
ok(-e $data->{from_file}, "file __FILE__ exists");
is($data->{from_caller}, $exp_file, "expected source path from (caller)[1]");
ok(-e $data->{from_caller}, "file (caller)[1] exists");
