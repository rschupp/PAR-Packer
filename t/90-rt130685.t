#!/usr/bin/perl

use strict;
use warnings;

use Config;
use Cwd;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

use Test::More;
require "./t/utils.pl";

# check that "pp -p" (without "-B") implies "pack no core modules"

my @core_modules = qw( Carp Exporter File::Glob List::Util );

plan tests => 2 * @core_modules;

# Note: There may be dual-life core modules installed.
# PAR::Packer won't consider them "core" unless it finds them in $Config{archlibexp} 
# or $Config{privlibexp}.

my ($privlib, $archlib) = map { (my $lib = $_) =~ s{\\}{/}g; $lib } 
                              @Config{qw(privlibexp archlibexp)};

foreach my $mod (@core_modules)
{
    (my $file = "$mod.pm") =~ s{::}{/}g;
    require $file;
    (my $path = Cwd::realpath($INC{$file})) =~ s{\\}{/}g;
    diag("found core module $mod in $path");

    SKIP: 
    {
        if ($path eq "$privlib/$file" || $path eq "$archlib/$file")
        {
            # check that "pp -p ..."  doesn't contain "lib/$file"
            my $par = pp_ok(-p => -e => "use $mod;");

            my $zip = Archive::Zip->new();
            $zip->read($par) == AZ_OK 
                or die qq[can't open par file "$par"];

            ok(!$zip->memberNamed("lib/$file"), ".par file doesn't contain core module $mod");
        }
        else
        {
            skip "your $mod is not a core module (according to PAR::Packer)", 2;
        }
    }
}
