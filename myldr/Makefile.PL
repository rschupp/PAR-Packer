#!/usr/bin/perl -w
# Copyright 2002-2009 by Audrey Tang.
# Copyright (c) 2002 Mattia Barbon.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use strict;
use Config;
use File::Spec;
use ExtUtils::Embed;
use ExtUtils::MakeMaker;
use DynaLoader;
use File::Basename;

xsinit(undef);

# used for searching libperls.
sub find_file {
    my $file = shift;

    my @paths = (
	    $Config{bin},
    	File::Spec->catdir($Config{'archlibexp'}, 'CORE'),
	    split(/\Q$Config{path_sep}\E/, $ENV{$Config{ldlibpthname}} || ''),
    	split(/ /, $Config{libpth}),
    );

    my $libperl;
    if ($libperl = DynaLoader::dl_findfile("-lperl")) {
        if (-l $libperl) {
            my $realpath = readlink($libperl);
            if (!File::Spec->file_name_is_absolute($realpath)) {
                $realpath = File::Spec->rel2abs(
                    File::Spec->catfile(
                        dirname($libperl) => $realpath
                    )
                );
            }
            $libperl = $realpath;
        }
        return $libperl if -e $libperl;
    }

    foreach my $path (@paths) {
	    $libperl = File::Spec->catfile($path, $file);
    	return $libperl if -e $libperl;
        
    	# for MinGW
	    $libperl = File::Spec->catfile($path, $1) if $file =~ /^lib(.+)/;
    	return $libperl if -e $libperl;
        
       	# for Cygwin
    	$libperl = File::Spec->catfile($path, $file.$Config{_a});
    	return $libperl if -e $libperl;
    }
}

my $debug = $ENV{DEBUG};
my $chunk_size = 30000;
my $exe = $Config{_exe};
my $link_exe = (($^O eq 'os2' and $Config{ldflags} =~ /-Zexe/) ? '' : $exe);
my $o = $Config{obj_ext};
my $gccversion = $Config{gccversion};
my $pccflags = ccopts();
my $pldflags = ldopts();
my $dynperl = $Config{useshrplib} && ($Config{useshrplib} ne 'false');

$dynperl = 1 if $pldflags =~ /\B-lperl\b/; # Gentoo lies to us!

my $cc = $Config{cc};
my $ld = $Config{ld} || (($^O eq 'MSWin32') ? 'link.exe' : $Config{cc});
$ld = $Config{cc} if ($^O =~ /^(?:dec_osf|aix|hpux)$/);

my $f2c = File::Spec->catfile('.', "file2c.pl");
my $par_pl = File::Spec->catfile('..', 'script', "par.pl");
my $par_exe = File::Spec->catfile('.', "par$exe");
my $par_exe_link = File::Spec->catfile('.', "par$link_exe");
my $boot_exe = File::Spec->catfile('.', "boot$exe");
my $boot_exe_link = File::Spec->catfile('.', "boot$link_exe");
my $parl_exe = "parl$exe";
my $parldyn_exe = "parldyn$exe";


my( $out, $ccdebug, $lddebug, $warn, $rm, $mv, $res, $mt_cmd, $res_cmd, $res_section, $rt_cmd, $pre_res );

$res = '';
$pre_res = '';
$res_cmd = '-$(NOOP)';
$rt_cmd = '-$(NOOP)';
$res_section = 'noresource.o'; # is never built

if( $cc =~ m/^cl\b/i ) {
    $out = '-out:';
    $ccdebug = $debug ? '-Zi -Zm1000 ' : '-Zm1000 ';
    $lddebug = $debug ? '-debug ' : '-release ';
    $warn = $debug ? '-W3' : '';
    my $machinearch = ( $Config{ptrsize} == 8 ) ? 'AMD64' : 'X86';
   $pre_res = qq(winres\\pp.res);
   $rt_cmd = qq(rc winres\\pp.rc);
    $res_cmd = qq(cvtres /NOLOGO /MACHINE:$machinearch /OUT:ppresource.obj $pre_res);
    $res = 'ppresource.obj';
   $res_section = $res;
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
    if( $^O =~ /^(?:MSWin|cygwin)/ ){
   $res = 'ppresource.coff';
   $pre_res = qq(winres\\pp.res);
   $rt_cmd = qq(windres -F pei-i386 -i winres\\pp.rc -o $pre_res);
   $res_cmd = qq(windres -o ppresource.coff $pre_res);
   $res_section = $res;
    }
    $mt_cmd = '-$(NOOP)';
} else {
    $out = '-o ';
    $ccdebug = '';
    $lddebug = '';
    $warn = '';
    $mt_cmd = '-$(NOOP)';
}


my $perl58lib = "";
if($ENV{ACTIVEPERL_MINGW} and $Config{cf_email}=~/ActiveState.com/i){
    chomp $pldflags;
    $perl58lib = "-l$Config{libperl}";
    $perl58lib =~ s/\.lib$//;
}
my $cflags = "$ccdebug$warn$pccflags";
my $optimize = $Config{optimize};
my $ldflags = "$lddebug$pldflags $perl58lib";
my $static_ldflags = $ldflags;

$static_ldflags =~ s/\s+-lperl\s+/ /g;

my $libperl;

if ($dynperl and $^O eq 'os2') {
    $libperl = OS2::DLLname();
}
elsif ($dynperl) {
    my $file = $Config{libperl};
    my $so = $Config{so} || 'so';
    $file = "libperl.$so" if $file eq 'libper'; # workaround Red Hat bug

    $file =~ s/\.(?!\d)[^.]*$/.$Config{so}/;
    $file =~ s/^lib// if $^O eq "MSWin32";

    $libperl = find_file($file);
    if (not -e $libperl) {
        $file =~ s/\.(?!\d)[^.]*$/.a/;
        $libperl = find_file($file);
    }

    # die "Can't find $file in (@paths) -- please contact the author!"
    # 	unless -e $libperl;
    undef $dynperl if !-e $libperl;
}

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
} else {
    my $file = $Config{libperl};
    $file = 'libperl.a' if $file eq 'libper'; # same redhat bug? Just making sure...
    $libperl = find_file($file);
    $ldflags = $static_ldflags;
}

my $par = (($dynperl && $^O ne 'os2') ? $boot_exe : $par_exe);


# If on Windows and Perl was built with GCC 4.x, then libperl*.dll
# may depend on some libgcc*.dll (Strawberry Perl 5.12 is an example).
# This libgcc*.dll has to be included into with any packed executbale 
# in the same way as libperl*.dll itself, otherwise a packed executable
# won't run when libgcc*.dll isn't installed.
my $libgcc;
if ($dynperl and $^O eq 'MSWin32'
    and defined $Config{gccversion}     # gcc version 4.x or above was used
    and $Config{gccversion} =~ m{\A(\d+)}ms && $1 >= 4) {
    # look for a libgcc_*.dll 
    # - in the same directory as the perl executable itself
    # - in the same directory as gcc (only useful if it's an absolute path)
    # - in PATH
    ($libgcc) = map { glob(File::Spec->catfile($_, "libgcc_*.$Config{so}")) }
                    File::Basename::dirname($^X),
                    File::Basename::dirname($cc),
                    File::Spec->path;
}
$libgcc ||= "";

my $my_stuff = "my_par.c my_libperl.c";
if ($libgcc) {
    $cflags .= " -DLOAD_MY_LIBGCC";
    $my_stuff .= " my_libgcc.c";
}


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
    PM          => { map { $_ => File::Spec->catfile('$(INST_LIBDIR)', qw( PAR StrippedPARL ), $_) }
                     @strippedparl },
    MAN3PODS    => {},
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

$res_section:
	$rt_cmd
	$res_cmd

clean::
	-\$(RM_F) my_*.c
	-\$(RM_F) main$o boot$o $res $pre_res
	-\$(RM_F) sha1.c
	-\$(RM_F) *.opt *.pdb perlxsi.c
	-\$(RM_F) usernamefrompwuid.h
	-\$(RM_F) $par_exe $boot_exe @parl_exes Dynamic.pm Static.pm

$par_exe: \$(OBJECTS)
	\$(LD) \$(OBJECTS) \$(PERL_LDFLAGS) $out$par_exe_link
	$mt_cmd

my_par_pl.c: $par_pl
	\$(PERLRUN) $f2c -s $par_pl \$@ load_my_par_pl

$parl_exe: $par
	\$(PERLRUN) -Mblib run_with_inc.pl $par -q -B -O\$@

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
	\$(PERLRUN) -Mblib run_with_inc.pl $par_exe -q -B -O\$@

boot$o: \$(MKTMP_STUFF) $my_stuff

$boot_exe: boot$o
	\$(LD) boot$o \$(STATIC_LDFLAGS) $res $out$boot_exe_link
	$mt_cmd

my_par.c: $par_exe
	\$(PERLRUN) $f2c -c $chunk_size $par_exe \$@ load_my_par

my_libperl.c:
	\$(PERLRUN) $f2c -c $chunk_size -n $extract_libperl_as $libperl \$@ load_my_libperl

my_libgcc.c:
	\$(PERLRUN) $f2c -c $chunk_size $libgcc \$@ load_my_libgcc

Dynamic.pm: Dynamic.in $par_exe
	\$(PERLRUN) encode_append.pl Dynamic.in $par_exe Dynamic.pm
EOT

    return $make_frag;
}

# local variables:
# mode: cperl
# end:
