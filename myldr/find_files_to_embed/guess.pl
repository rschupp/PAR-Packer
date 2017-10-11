#!perl

use strict;
use warnings;
use Config;
use File::Glob;
use File::Basename;
use File::Spec;

my $ld = $Config{ld} || (($^O eq 'MSWin32') ? 'link.exe' : $Config{cc});
$ld = $Config{cc} if ($^O =~ /^(?:dec_osf|aix|hpux)$/);

sub find_files_to_embed
{
    my ($par, $libperl) = @_;

    # If on Windows and Perl was built with GCC 4.x or higher, then libperl*.dll
    # may depend on some libgcc_*.dll (e.g. Strawberry Perl 5.12).
    # This libgcc_*.dll has to be included into with any packed executable 
    # in the same way as libperl*.dll itself, otherwise a packed executable
    # won't run when libgcc_*.dll isn't installed.
    # The same holds for libstdc++*.dll (e.g. Strawberry Perl 5.16).
    my ($libgcc, $libstdcpp, $libwinpthread);
    if ($^O eq 'MSWin32'
        and defined $Config{gccversion}             # gcc version >= 4.x was used
        and $Config{gccversion} =~ m{\A(\d+)}ms && $1 >= 4) {
            $libgcc = find_dll("libgcc_*.$Config{so}");
            $libwinpthread = find_dll("libwinpthread*.$Config{so}");
    }
    if ($ld =~ /(\b|-)g\+\+(-.*)?(\.exe)?$/) {      # g++ was used to link
        $libstdcpp = find_dll("libstdc++*.$Config{so}");
    }

    return { map { basename($_) => $_ } 
                 grep { defined } $libperl, $libgcc, $libwinpthread, $libstdcpp };
}

sub find_dll
{
    my ($dll_glob) = @_;

    # look for $dll_glob
    # - in the same directory as the perl executable itself
    # - in the same directory as gcc (only useful if it's an absolute path)
    # - in PATH
    my ($dll_path) = map { File::Glob::bsd_glob(File::Spec->catfile($_, $dll_glob)) }
                         dirname($^X),
                         dirname($Config{cc}),
                         File::Spec->path();
    return $dll_path;
}

1;
