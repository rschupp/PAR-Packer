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

    # search for the "\nPAR.pm\n signature backward from the end of the file
    my $buf;
    my $size = -s $exe;
    my $offset = 512;
    my $idx = -1;
    while (1)
    {
        $offset = $size if $offset > $size;
        seek $fh, -$offset, 2 or die qq[seek failed on "$exe": $!];
        my $nread = read $fh, $buf, $offset;
        die qq[read failed on "$exe": $!] unless $nread == $offset;
        $idx = rindex($buf, "\nPAR.pm\n");
        last if $idx >= 0 || $offset == $size || $offset > 128 * 1024;
        $offset *= 2;
    }
    die qq[no PAR signature found in "$exe"] unless $idx >= 0;

    # seek 4 bytes backward from the signature to get the offset of the 
    # first embedded FILE, then seek to it
    $offset -= $idx - 4;
    seek $fh, -$offset, 2;
    read $fh, $buf, 4;
    seek $fh, -$offset - unpack("N", $buf), 2;
    printf STDERR qq[embedded files in "%s" start at offset %d\n], $exe, tell($fh);

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
