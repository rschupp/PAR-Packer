#!/usr/bin/perl

use strict;
use warnings;

use Archive::Zip qw( :ERROR_CODES );

use Test::More;
require "./t/utils.pl";

my %expected = (
    "Double::Colon" => [qw(
            lib/Double/Colon.pm
        )],
    "Double::Colon::" => [qw(
            lib/Double/Colon.pm
            lib/Double/Colon/Barnie.pm
            lib/Double/Colon/Foo/Bar/Quux.pm
            lib/Double/Colon/Fred.pm
        )],
    "Double::Colon::*" => [qw(
            lib/Double/Colon/Barnie.pm
            lib/Double/Colon/Fred.pm
        )],
    "Double::Colon::**" => [qw(
            lib/Double/Colon/Barnie.pm
            lib/Double/Colon/Foo/Bar/Quux.pm
            lib/Double/Colon/Fred.pm
        )],
);

plan tests => 2 * (keys %expected);


while (my ($M, $exp) = each %expected) 
{
    my $exe = pp_ok(-I => "t", -M => $M,
                    -e => q[print qq[testing 'pp -M Foo::' and variants\n]]);

    my $zip = Archive::Zip->new();
    $zip->read($exe) == AZ_OK or die "can't read $exe as a zip file";

    my @double_colons = sort grep { m{Double/Colon} } 
                                  map { $_->fileName() }
                                      grep { !$_->isDirectory() } 
                                           $zip->members();
    is("@double_colons", "@$exp", "modules for '-M$M'");
}
