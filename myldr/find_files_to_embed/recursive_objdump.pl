#!perl

use strict;
use warnings;
use File::Basename;
use Cwd;
use File::Spec;
use DynaLoader;

my $system_root = Cwd::abs_path($ENV{SystemRoot});

sub is_system_lib { Cwd::abs_path(shift) =~ m{^\Q$system_root\E/}i }

sub find_files_to_embed
{
    my ($par, $libperl) = @_;

    return recursive_objdump($par, dirname($^X));
}

sub recursive_objdump
{
    my ($path, @search_first_in) = @_;

    # NOTE: Looks like Perl on Windows (e.g. Strawberry) doesn't set 
    # $Config{ldlibpthname} - one could argue that its value should be "PATH".
    # But even where it is defined (e.g. "LD_LIBRARY_PATH" on Linux)
    # DynaLoader *appends* (an appropriately split)
    # $ENV{$Config{ldlibpthname}} to its search path, @dl_library_path, 
    # which is wrong in our context as we want it to be searched first.
    # Hence, provide our own value for @dl_library_path.
    local @DynaLoader::dl_library_path = (@search_first_in, File::Spec->path());

    my %dlls;
    my %seen;
    my $walker;
    $walker = sub 
    {
        my ($obj) = @_;
        return if $seen{lc $obj}++;

        my $out = qx(objdump -ax "$obj");
        die "objdump failed: $!\n" unless $? == 0;

        foreach my $dll ($out =~ /^\s*DLL Name:\s*(\S+)/gm)
        {
            next if $dlls{lc $dll};             # already found

            my ($file) = DynaLoader::dl_findfile($dll) or next;
            $dlls{lc $dll} = $file;

            next if is_system_lib($file);       # no need to recurse on a system library
            $walker->($file);                   # recurse
        }
    };
    $walker->(Cwd::abs_path($path));

    # weed out system libraries
    foreach my $name (keys %dlls)
    {
        delete $dlls{$name} if is_system_lib($dlls{$name});
    }
        
    return \%dlls;
}

1;
