#!perl

# Copyright (c) 2002 Mattia Barbon.
# Copyright (c) 2002 Audrey Tang.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use IO::Compress::Gzip qw(gzip $GzipError);

my $chunk_size = 32768;
my $compress = 0;

GetOptions(
    "c|chunk-size=i"    => \$chunk_size,
    "z|compress"        => \$compress)
    && @ARGV == 3
        or die "Usage: $0 [-c CHUNK][-z] par method libperl > file.c\n";
my ($par, $method, $libperl) = @ARGV;

print STDERR qq[# using method $method to find files to embed\n];
require "./find_files_to_embed/$method.pl";

my $files_to_embed = find_files_to_embed($par, $libperl);

my $filenn = "file00";    # 100 files should be enough
my @embedded;

# par is always the first embedded file
push @embedded, embed($filenn++, basename($par), $par);

while (my ($name, $file) = each %$files_to_embed)
{
    push @embedded, embed($filenn++, $name, $file);
}

print "static embedded_file_t embedded_files[] = {\n";
print "  { \"$_->{name}\", $_->{size}, $_->{chunks} },\n" foreach @embedded;
print "  { NULL, 0, NULL }\n};";
           
exit 0;

sub embed
{
    my ($prefix, $name, $file) = @_;
    print STDERR qq[# embedding "$file" as "$name"\n];
    
    return { name => $name, size => -s $file, chunks => file2c($prefix, $file) };
}

sub file2c
{
    my ($prefix, $path) = @_;

    my $bin = do           # a scalar reference
    {
        open my $in, "<", $path or die "open input file '$path': $!";
        binmode $in;
        local $/ = undef;
        my $slurp = <$in>;
        close $in;
        \$slurp;
    };


    if ($compress)
    {
        my $gzipped;
        my $status = gzip($bin, \$gzipped)
            or die "gzip failed: $GzipError\n";
        $bin = \$gzipped;
    }

    my $len = length $$bin;
    my $chunk_count = int(( $len + $chunk_size - 1 ) / $chunk_size);

    my @chunks;
    for (my $offset = 0, my $i = 0; $offset <= $len; $offset += $chunk_size, $i++)
    {
        my $name = "${prefix}_${i}";
        push @chunks, { 
               name => $name,
               len  => print_chunk(substr($$bin, $offset, $chunk_size), $name),
        };
    } 

    print "static chunk_t ${prefix}[] = {\n";
    print "  { $_->{len}, $_->{name} },\n" foreach @chunks;
    print "  { 0, NULL } };\n\n";

    return $prefix;
}

sub print_chunk 
{
    my ($chunk, $name) = @_;

    my $len = length($chunk);
    print qq[static unsigned char ${name}[] =];
    my $i = 0;
    do
    {
        print qq[\n"];
        while ($i < $len)
        {
            printf "\\x%02x", ord(substr($chunk, $i++, 1));
            last if $i % 16 == 0;
        }
        print qq["];
    } while ($i < $len);
    print ";\n";
    return $len;
}

# local variables:
# mode: cperl
# end:
