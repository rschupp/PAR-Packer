#!perl
# Copyright 2002-2009 by Audrey Tang.
# Copyright (c) 2002 Mattia Barbon.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use warnings;
use Config;
use File::Spec::Functions ':ALL';
use ExtUtils::Embed;
use ExtUtils::MakeMaker;
use DynaLoader;
use File::Basename;
use File::Glob;

xsinit(undef);

# used for searching libperls.
sub find_file {
    my $file = shift;

    my @paths = (
	$Config{bin},
    	catdir($Config{'archlibexp'}, 'CORE'),
	split(/\Q$Config{path_sep}\E/, $ENV{$Config{ldlibpthname}} || ''),
    	split(/ /, $Config{libpth}),
    );

    my $libperl;
    if ($libperl = DynaLoader::dl_findfile("-lperl")) {
        if (-l $libperl) {
            my $realpath = readlink($libperl);
            if (!file_name_is_absolute($realpath)) {
                $realpath = rel2abs(catfile(dirname($libperl), $realpath));
            }
            $libperl = $realpath;
        }
        return $libperl if -e $libperl;
    }

    foreach my $path (@paths) {
	    $libperl = catfile($path, $file);
    	return $libperl if -e $libperl;
        
    	# for MinGW
	    $libperl = catfile($path, $1) if $file =~ /^lib(.+)/;
    	return $libperl if -e $libperl;
        
       	# for Cygwin
    	$libperl = catfile($path, $file.$Config{_a});
    	return $libperl if -e $libperl;
    }
}

my $debug = $ENV{DEBUG};
my $chunk_size = 30000;
my $exe = $Config{_exe};
my $link_exe = (($^O eq 'os2' and $Config{ldflags} =~ /-Zexe/) ? '' : $exe);
my $o = $Config{obj_ext};
my $gccversion = $Config{gccversion};
# NOTE: on some platforms, ccopts or ldopts may contain newlines
chomp( my $pccflags = ccopts() );
chomp( my $pldflags = ldopts() );
my $dynperl = $Config{useshrplib} && ($Config{useshrplib} ne 'false');

$dynperl = 1 if $pldflags =~ /\B-lperl\b/; # Gentoo lies to us!

my $cc = $Config{cc};
my $ld = $Config{ld} || (($^O eq 'MSWin32') ? 'link.exe' : $Config{cc});
$ld = $Config{cc} if ($^O =~ /^(?:dec_osf|aix|hpux)$/);

my $f2c = catfile('.', "file2c.pl");
my $par_pl = catfile('..', 'script', "par.pl");
my $par_exe = catfile('.', "par$exe");
my $par_exe_link = catfile('.', "par$link_exe");
my $boot_exe = catfile('.', "boot$exe");
my $boot_exe_link = catfile('.', "boot$link_exe");
my $parl_exe = "parl$exe";
my $parldyn_exe = "parldyn$exe";

my( $out, $ccdebug, $lddebug, $warn, $rm, $mv, $mt_cmd );

my $res = '';
my $res_section = '';
my $boot_ldflags = '';

if( $cc =~ m/^cl\b/i ) {
    $out = '-out:';
    $ccdebug = $debug ? '-Zi -Zm1000 ' : '-Zm1000 ';
    $lddebug = $debug ? '-debug ' : '-release ';
    $warn = $debug ? '-W3' : '';
    my $machinearch = ( $Config{ptrsize} == 8 ) ? 'AMD64' : 'X86';
    $res = 'ppresource.obj';
    $res_section = <<"...";
$res:
	rc winres\\pp.rc
	cvtres /NOLOGO /MACHINE:$machinearch /OUT:$res winres\\pp.res
...

    # Embed the manifest file for VC 2005 (aka VC8) or higher, but not for the
    # 64-bit Platform SDK compiler.
    if( $Config{ptrsize} == 4 and $Config{ccversion} =~ /^(\d+)/ and $1 >= 14 ) {
        $mt_cmd = 'mt -nologo -manifest $@.manifest -outputresource:$@;1';
    } else {
        $mt_cmd = '-$(NOOP)';
    }
} elsif ($cc =~ m/\bgcc\b/i or ($cc =~ m/\bcc\b/i and $gccversion)) {
    $out = '-o ';
    $ccdebug = $debug ? '-g ' : '';
    $lddebug = ($debug or $^O eq 'darwin') ? '' : '-s ';
    $warn = $debug ? '-Wall -Wno-comments ' : '';
    if ( $^O =~ /^(?:MSWin|cygwin)/ ) {
        my $target = $Config{archname} =~ /x64/ ? 'pe-x86-64' : 'pe-i386';
        $res = 'ppresource.coff';
        # Note: On cygwin the command below will be processed by the
        # cygwin shell, so backslashes in pathnames might be a problem.
        # Instead use forward slashes which work on Windows as well.
        $res_section = <<"...";
$res:
	windres -i winres/pp.rc -o $res --input-format=rc --output-format=coff --target=$target
...
    }
    $mt_cmd = '-$(NOOP)';
    $boot_ldflags .= '-static-libgcc ' if $^O eq 'MSWin32';
} else {
    $out = '-o ';
    $ccdebug = '';
    $lddebug = '';
    $warn = '';
    $mt_cmd = '-$(NOOP)';
}


my $perl58lib = "";
if($ENV{ACTIVEPERL_MINGW} and $Config{cf_email}=~/ActiveState.com/i){
    $perl58lib = "-l$Config{libperl}";
    $perl58lib =~ s/\.lib$//;
}
my $cflags = "$ccdebug$warn$pccflags";
my $optimize = $Config{optimize};
my $ldflags = "$lddebug$pldflags $perl58lib";
my $static_ldflags = $ldflags;

my $libperl;

if ($dynperl and $^O eq 'os2') {
    $libperl = OS2::DLLname();
}
elsif ($dynperl) {
    my $file = $Config{libperl};
    my $so = $Config{so} || 'so';
    $file = "libperl.$so" if $file eq 'libper'; # workaround Red Hat bug

    $file =~ s/\.(?!\d)[^.]*$/.$Config{so}/;
    $file =~ s/^lib// if $^O eq 'MSWin32';

    $libperl = find_file($file);
    if (not -e $libperl) {
        $file =~ s/\.(?!\d)[^.]*$/.a/;
        $libperl = find_file($file);
    }

    # die "Can't find $file in (@paths) -- please contact the author!"
    # 	unless -e $libperl;
    undef $dynperl if !-e $libperl;
}

my $perllibshortname = 'perl';
if ($dynperl) {
    $perllibshortname = basename($libperl);
    my $so = $Config{so} || 'so';
    $perllibshortname =~ s/^lib//;
    $perllibshortname =~ s/\Q.$so\E$//;
}
$static_ldflags =~ s/(^|\s)-l$perllibshortname(\s|$)/ /g;
$boot_ldflags .= $static_ldflags;


# In the $dynperl case, we've already found the $libperl DSO.
# The only problem is: when the linker links $par_exe against $libperl
# we don't know what name is used to refer to $libperl in the executable
# (e.g. on an ELF based system the DT_NEEDED tag). This is the name
# the dynamic loader is looking for when $par_exe is executed.
#
# So we better make sure that $libperl is extracted using this name
# during bootstrap of a packed executable. If we use the wrong name for
# extraction, $libperl won't be considered by the dynamic loader.
# This may cause the bootstrap to fail. Or the dynamic loader 
# might find a libperl DSO (e.g in /usr/lib using the built-in library
# search path) from a Perl installation with the expected name.
# However, this libperl may be ABI incompatible with $par_exe,
# leading to hard to diagnose errors.
#
# Below we make a feeble attempt to determine this "link name" for some
# well-known platforms. The fallback is always the basename of $libperl.
# For ELF based systems the linker uses the DSO's DT_SONAME tag
# as the link name if present. If the system uses the GNU binutils
# toolchain we can use the objdump tool to find the DSO's soname.

my $extract_libperl_as;
if ($dynperl) {
    $extract_libperl_as = basename($libperl);
    if ($^O =~ /linux/i) 
    {
        my ($soname) = qx(objdump -ax $libperl) =~ /^\s*SONAME\s+(\S+)/m;
        $extract_libperl_as = $soname if $? == 0 && defined $soname;
    }
    # on Debian derived distros make sure that the Debian package "libperl-dev"
    # is installed (which contains the /usr/lib/libperl.so symlink)
    die qq[You need to install the distro (Debian, Ubuntu etc) package "libperl-dev"\n] 
       if $^O =~ /^(linux|gnukfreebsd)$/i
          && -x "/usr/bin/dpkg"                 
                # probably Debian or a derivative
          && system("dpkg -S $^X >/dev/null 2>&1") == 0 
                # we're building with the system (distro) perl
          && system("dpkg -l libperl-dev >/dev/null 2>&1") != 0;
                # check install status of libperl-dev
} else {
    my $file = $Config{libperl};
    $file = 'libperl.a' if $file eq 'libper'; # same redhat bug? Just making sure...
    $libperl = find_file($file);
    $ldflags = $static_ldflags;
}

my $par = (($dynperl && $^O ne 'os2') ? $boot_exe : $par_exe);


# If on Windows and Perl was built with GCC 4.x, then libperl*.dll
# may depend on some libgcc_*.dll (e.g. Strawberry Perl 5.12).
# This libgcc_*.dll has to be included into with any packed executable 
# in the same way as libperl*.dll itself, otherwise a packed executable
# won't run when libgcc_*.dll isn't installed.
# The same holds for libstdc++*.dll (e.g. Strawberry Perl 5.16).

sub find_dll
{
    my ($dll_glob) = @_;

    # look for $dll_glob
    # - in the same directory as the perl executable itself
    # - in the same directory as gcc (only useful if it's an absolute path)
    # - in PATH
    my ($dll_path) = map { File::Glob::bsd_glob(catfile($_, $dll_glob)) }
                         dirname($^X),
                         dirname($cc),
                         path();
    return $dll_path;
}


my ($libgcc, $libstdcpp, $libwinpthread);
if ($dynperl and $^O eq 'MSWin32'
    and defined $Config{gccversion}             # gcc version >= 4.x was used
    and $Config{gccversion} =~ m{\A(\d+)}ms && $1 >= 4) {
    $libgcc = find_dll("libgcc_*.$Config{so}");
    $libwinpthread = find_dll("libwinpthread*.$Config{so}");
}
if ($ld =~ /(\b|-)g\+\+(-.*)?(\.exe)?$/) {      # g++ was used to link
    $libstdcpp = find_dll("libstdc++*.$Config{so}");
}

# enclose the filenames in double quotes
# NOTE: This quoting is not perfect (e.g. won't protect dollar signs
# or double quotes in filenames), but should work in all reasonable
# scenarios on both *nix and Windows).
my @embedded_files = map{ qq["$_"] } grep { defined } 
    $par_exe,       # must come first
    $libperl,
    $libgcc,
    $libwinpthread,
    $libstdcpp;

my @strippedparl = qw( Static.pm );
push @strippedparl, qw( Dynamic.pm ) if $dynperl;
my @parl_exes = $parl_exe;
push @parl_exes, $parldyn_exe if $dynperl;


# Determine whether we can find a config.h. If yes, include it in
# usernamefrompwuid.h. If not, set I_PWD to undefined in that header.
# -- Steffen
my $configh = "$Config::Config{archlibexp}/CORE/config.h";
open PWOUT, '> usernamefrompwuid.h' or die "open 'usernamefrompwuid.h': $!";
if (not -f $configh) {
    print PWOUT "#undef I_PWD\n";
}
else {
    print PWOUT "#include \"$configh\"\n";
}
close PWOUT;


WriteMakefile(
    NAME        => "par$exe",
    SKIP        => [qw(static static_lib dynamic dynamic_lib test)],
    NO_META     => 1,
    PL_FILES    => {},
    PM          => { map { $_ => catfile('$(INST_LIBDIR)', qw( PAR StrippedPARL ), $_) }
                     @strippedparl },
    MAN1PODS    => {},
    EXE_FILES   => \@parl_exes,
    macro       => { FIXIN => '$(NOOP)' },
);

sub MY::postamble
{
    my $make_frag = <<"EOT";
LD=$ld
CC=$cc
CFLAGS=$cflags -DPARL_EXE=\\"parl$exe\\"
OPTIMIZE=$optimize
LDFLAGS=$Config{ldflags}
PERL_LDFLAGS=$ldflags
STATIC_LDFLAGS=$static_ldflags

OBJECTS=main$o $res
MKTMP_STUFF=mktmpdir.c mktmpdir.h utils.c sha1.c

.c$o:
	\$(CC) -c \$(CFLAGS) \$(OPTIMIZE) \$<

pure_all:: $parl_exe Static.pm

main$o: main.c my_par_pl.c perlxsi.c internals.c \$(MKTMP_STUFF)

sha1.c:
	\$(PERLRUN) sha1.c.PL

$res_section

clean::
	-\$(RM_F) boot_embedded_files.c my_par_pl.c
	-\$(RM_F) main$o boot$o $res
	-\$(RM_F) sha1.c
	-\$(RM_F) *.opt *.pdb perlxsi.c
	-\$(RM_F) usernamefrompwuid.h
	-\$(RM_F) $par_exe $boot_exe @parl_exes Dynamic.pm Static.pm

$par_exe: \$(OBJECTS)
	\$(LD) \$(OBJECTS) \$(PERL_LDFLAGS) $out$par_exe_link
	$mt_cmd

my_par_pl.c: $par_pl
	\$(PERLRUN) par_pl2c.pl my_par_pl < $par_pl > \$@ 

$parl_exe: $par
	\$(PERLRUN) -Mblib=.. run_with_inc.pl $par -q -B -O\$@

Static.pm: Static.in $par
	\$(PERLRUN) encode_append.pl Static.in $par Static.pm


.DEFAULT:
	-\$(NOOP)

.SUFFIXES: $o

# dummy targets to satisfy ExtUtils::MakeMaker
dynamic::
static::
test::
EOT

    $make_frag .= <<"EOT" if $dynperl;

pure_all:: $parldyn_exe Dynamic.pm

$parldyn_exe: $par_exe
	\$(PERLRUN) -Mblib=.. run_with_inc.pl $par_exe -q -B -O\$@

boot$o: \$(MKTMP_STUFF) boot_embedded_files.c

$boot_exe: boot$o
	\$(LD) boot$o $boot_ldflags $res $out$boot_exe_link
	$mt_cmd

boot_embedded_files.c: $par_exe
	\$(PERLRUN) $f2c -c $chunk_size @embedded_files > \$@

Dynamic.pm: Dynamic.in $par_exe
	\$(PERLRUN) encode_append.pl Dynamic.in $par_exe Dynamic.pm
EOT

    return $make_frag;
}

# local variables:
# mode: cperl
# end:
