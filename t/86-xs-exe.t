#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
require "./t/utils.pl";

plan tests => 6;

my $exe = pp_ok(-I => "t/data/blib/lib", -I => "t/data/blib/arch", -e => <<'...');
use XSFoo; 
XSFoo::hello();

use DynaLoader;
print qq[dl_shared_objects = @DynaLoader::dl_shared_objects\n];
print qq[dl_modules = @DynaLoader::dl_modules\n];
...

my ($out, $err) = run_ok($exe);
like($out, qr/greetings from XSFoo/, "output from XSFoo::hello matches");

diag($out);
$out =~ s:\\:/:g;
my ($shared_objects) = $out =~ /^dl_shared_objects = (.*)$/m;
ok($shared_objects, "dl_shared_objects found");
my ($modules) = $out =~ /^dl_modules = (.*)$/m;
ok($modules, "dl_modules found");
ok((grep { $_ eq "XSFoo" } split(" ", $modules, -1)),
   "dl_modules contains XSFoo DLL");
