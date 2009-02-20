#!/usr/bin/perl 
# Script stolen from one of Roderich Schupp's mails to the PAR
# mailing list. He attributes this to:

# code stolen from PAR script/parl.pl

use File::Spec;
use File::Basename;
use File::Path;
use strict;
use warnings;

@ARGV == 2 || die "usage: $0 executable directory_to_extract_into\n";
extract_embedded(@ARGV);

sub extract_embedded
{
    my ($exe, $xdir) = @_;

    open my $fh, '<', $exe or die qq[failed to open "$exe": $!];
    binmode $fh;

    my $buf;
    seek $fh, -8, 2;
    read $fh, $buf, 8;
    die qq[no PAR signature found in "$exe"] unless $buf eq "\nPAR.pm\n";

    seek $fh, -12, 2;
    read $fh, $buf, 4;
    seek $fh, -12 - unpack("N", $buf), 2;
    read $fh, $buf, 4;

    while ($buf eq "FILE") 
    {
        read $fh, $buf, 4;
        read $fh, $buf, unpack("N", $buf);

        my $fullname = $buf;
        print STDERR qq[FILE "$fullname"...];
        my $crc = ( $fullname =~ s|^([a-f\d]{8})/|| ) ? $1 : undef;
        my @path = split(/\//, $fullname);

        read $fh, $buf, 4;
        read $fh, $buf, unpack("N", $buf);

	my $file = File::Spec->catdir($xdir, @path);
	my $dir = dirname($file);
	mkpath($dir) unless -d $dir;

	open my $out, '>', $file or die qq[failed to open "$file": $!];
	binmode $out;
	print $out $buf;
	close $out;
	print STDERR qq[ extracted to $file\n];

        read $fh, $buf, 4;
    }

    close $fh;
}
