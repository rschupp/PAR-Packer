#!/usr/bin/perl
use 5.008001;
use strict;
use inc::Module::Install 0.92;

name        'PAR-Packer';
abstract    'PAR Packager';
all_from    'lib/PAR/Packer.pm';

perl_version '5.008001';
configure_requires 'ExtUtils::Embed';
requires    'File::Temp'         => '0.05';
requires    'Compress::Zlib'     => ($^O eq 'MSWin32') ? '1.16' : '1.30';
requires    'IO::Compress::Gzip' => 0;
requires    'Archive::Zip'       => '1.00';
requires    'Module::ScanDeps'   => '1.17';
requires    'PAR::Dist'          => '0.22';
requires    'PAR'                => '1.005';
requires    'Text::ParseWords'   => 0;
requires    'Getopt::ArgvFile'   => '1.07';

if ($^O eq 'MSWin32') {
    requires  'Parse::Binary'    => '0.04';
    requires  'Win32::Exe'       => '0.17';
    requires  'Win32::Process'   => 0;
}

# for tkpp
recommends  'Tk'                 => 0;
recommends  'Tk::ColoredButton'  => 0;
recommends  'Tk::EntryCheck'     => 0;
recommends  'Tk::Getopt'         => 0;

# for digital signature support
recommends 'Digest'              => 0;
recommends 'Digest::SHA'         => 0;
recommends 'Module::Signature'   => 0;

include_deps        'Test::More';
no_index            directory => 'contrib';
auto_provides;

repository 'http://svn.openfoundry.org/par/PAR-Packer/trunk';

par_base 'SMUELLER';

if ($] == 5.010000) {
    # 5.10.0 breaks how PAR intercepts loading of shared libraries
    warn <<'...';
*** Perl version 5.10.0 is not supported.
    Please upgrade to 5.10.1 or better.
...
    exit 0;
}

if (defined($ENV{PERL5LIB}) || defined($ENV{PERLLIB})) {
    warn <<'...';
*** You have extra Perl library paths set in your environment.
    Please note that these paths (set with PERL5LIB or PERLLIB)
    are not honored by perl when running under taint mode, which
    may lead to problems. This is a limitation (by design) of
    Perl, not of PAR::Packer; but some of the problems may
    manifest here during installation.
...
}

par_prehook();
#WriteAll sign => 1;
WriteAll sign => 0;

my %no_parl  = ();

use strict; use warnings;
sub par_prehook {
    my $bork = $no_parl{$^O};
    my $cc;
    $cc = can_cc unless $bork;
    my $par;
    $par = fetch_par('', '', !$cc) unless ($cc or $bork);
    my $exe  = $Config::Config{_exe};
    my $dynperl = $Config::Config{useshrplib} && ($Config::Config{useshrplib} ne 'false');

    if ($bork) {
        warn "Binary loading known to fail on $^O; won't generate 'script/parl$exe'!\n";
    }
    elsif (!$par and !$cc) {
        warn "No compiler found, won't generate 'script/parl$exe'!\n";
    }


    # Do not run 10parl-generation tests in case of a pre built .par (doesn't work)
    my %tests = map { $_ => 1 } <t/*.t>;
    delete $tests{'t/10-parl-generation.t'} unless (!$par and $cc);

    makemaker_args(
        MAN1PODS		=> {
            'script/par.pl'	=> 'blib/man1/par.pl.1',
            'script/pp'	        => 'blib/man1/pp.1',
            'script/tkpp'       => 'blib/man1/tkpp.1',
          ($par or $cc) ? (
            'script/parl.pod'   => 'blib/man1/parl.1',
          ) : (),
        },
        EXE_FILES		=> [
            'script/par.pl',
            'script/pp',
            'script/tkpp',
        ],
        DIR                     => [
          (!$par and $cc) ? (
            'myldr'
          ) : (),
        ],
        NEEDS_LINKING	        => 1,
        test => { TESTS => join(" ", sort keys %tests) },
    );
}


1;
