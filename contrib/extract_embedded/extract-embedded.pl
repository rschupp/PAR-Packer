#!/usr/bin/perl
# Script stolen from one of Roderich Schupp's mails to the PAR
# mailing list. He attributes this to:

# code stolen from PAR script/parl.pl

use strict;
use warnings;

use File::Spec::Functions;
use File::Basename;
use File::Path;

@ARGV <= 2 or die <<"...";
Usage: $0 par-packed-executable [directory]

List (or extract) the "embedded files" (cf. PAR::Tutorial) in
an executable packed by PAR::Packer. If an optional directory is specified,
the embedded files are extracted into it, using their original file names.
...

my ($exe, $extract) = @ARGV;

sub safe_read
{
    my ($fh, $n) = @_;
    my $buf;
    my $res = read $fh, $buf, $n;
    die qq[read of $n bytes failed on "$exe": $!] unless defined $res;
    die qq[read of $n bytes failed on "$exe": at EOF] unless $res > 0;
    die qq[read of $n bytes failed on "$exe": only read $res bytes] unless $res == $n;
    return $buf;
}

sub safe_seek
{
    my ($fh, $offset, $whence) = @_;
    unless (seek $fh, $offset, $whence)
    {
        my $what = $whence == 0 ? "SET" : $whence == 1 ? "CUR" : "END";
        die qq[seek $what of $offset bytes failed on "$exe": $!];
    }
}

open my $fh, '<:raw', $exe or die qq[failed to open "$exe": $!];

# search for the "\nPAR.pm\n" signature backward from the end of the file
my $buf;
my $size = -s $exe;
my $offset = 512;
my $idx = -1;
while (1)
{
    $offset = $size if $offset > $size;
    safe_seek($fh, -$offset, 2);
    $buf = safe_read($fh, $offset);
    $idx = rindex($buf, "\012PAR.pm\012");
    last if $idx >= 0 || $offset == $size || $offset > 128 * 1024;
    $offset *= 2;
}
$offset -= $idx;
die qq[no PAR signature found in "$exe"] unless $idx >= 0;

# seek 4 bytes backward from the signature to get the offset of the
# first embedded FILE, then seek to it
$offset += 4;
safe_seek($fh, -$offset, 2);
$buf = safe_read($fh, 4);
safe_seek($fh, -$offset - unpack("N", $buf), 2);
printf STDERR qq[embedded files in "%s" start at offset %d\n], $exe, tell($fh);

my $nfiles = 0;
$buf = safe_read($fh, 4);
while ($buf eq "FILE")
{
    $nfiles++;

    $buf = safe_read($fh, 4);
    $buf = safe_read($fh, unpack("N", $buf));

    my ($crc, $fullname) = $buf =~ m|^((?i)[a-f\d]{8})/(.*)$|
        or die qq[unrecognized FILE spec: "$buf"];
    print "$crc  $fullname\n";

    $buf = safe_read($fh, 4);
    $buf = safe_read($fh, unpack("N", $buf));

    if ($extract)
    {
        my $file = catdir($extract, split(/\//, $fullname));
        my $dir = dirname($file);
        mkpath($dir) unless -d $dir;

        open my $out, '>:raw', $file or die qq[failed to open "$file": $!];
        print $out $buf;
        close $out;
        print STDERR qq[... extracted to $file\n];
    }

    $buf = safe_read($fh, 4);
}
printf STDERR qq[$nfiles embedded files found\n];

close $fh;

exit(0);
