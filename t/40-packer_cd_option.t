#!/usr/bin/perl
# $Id$

use strict;
use warnings;

use File::Temp ();

# Fake a frontend to see if caching options are correctly passed through
package TestFE;

my $cache_file_passed_in;

sub scan_deps{
    my %opts = @_;
    $cache_file_passed_in =  $opts{cache_file};
}
sub _find_in_inc{}
sub add_deps{}
sub init{
    $cache_file_passed_in = 0;
}

sub check{
    return $cache_file_passed_in;
}

package main;
use Test::More (tests => 2);
use PAR::Packer;

$ENV{PAR_TMPDIR} = File::Temp::tempdir(TMPDIR => 1, CLEANUP => 1);

for my $opt (qw/cd cachedeps/){
    TestFE::init();
    my $p = PAR::Packer->new();
    $p->set_options(
                    $opt => 'aFilename',
                    e  => 'print Test',
                );
    $p->set_args();
    $p->set_front( 'TestFE' );
    $p->go;

    is( TestFE::check(), 'aFilename', "Filename passed through via -$opt");
}
__END__
