#!/usr/bin/perl
use strict;
use warnings;

BEGIN { push @INC, '.' unless $INC[-1] eq '.' }
use inc::Module::Install 0.92;

name        'PAR-Packer';
abstract    'PAR Packager';
all_from    'lib/PAR/Packer.pm';

perl_version '5.008009';

configure_requires 'ExtUtils::Embed';
configure_requires 'DynaLoader';
configure_requires 'File::Basename';
configure_requires 'File::Glob';
configure_requires 'File::Spec::Functions';

requires    'File::Temp'         => '0.05';
requires    'Compress::Zlib'     => ($^O eq 'MSWin32') ? '1.16' : '1.30';
requires    'IO::Compress::Gzip' => 0;
requires    'Archive::Zip'       => '1.02';
requires    'Module::ScanDeps'   => '1.21';
requires    'PAR::Dist'          => '0.22';
requires    'PAR'                => '1.014';
requires    'Text::ParseWords'   => 0;
requires    'Getopt::ArgvFile'   => '1.07';

test_requires  'Test::More'      => 0;
test_requires  'Win32::Exe'      => '0.17' if $^O eq 'MSWin32';

# for tkpp
recommends  'Tk'                 => 0;
recommends  'Tk::ColoredButton'  => 0;
recommends  'Tk::EntryCheck'     => 0;
recommends  'Tk::Getopt'         => 0;
recommends  'Win32::Process'     => 0 if $^O eq 'MSWin32';

# for digital signature support
recommends 'Digest'              => 0;
recommends 'Digest::SHA'         => 0;
recommends 'Module::Signature'   => 0;

auto_provides;
no_index    directory           => 'contrib';

license     'perl_5';
resources   repository          => 'https://github.com/rschupp/PAR-Packer',
            MailingList         => 'par@perl.org';

if ($] == 5.010000) {
    # 5.10.0 breaks how PAR intercepts loading of shared libraries
    warn <<'...';
*** Perl version 5.10.0 is not supported.
    Please upgrade to 5.10.1 or better.
...
    exit 0;
}


{
    my $cc = can_cc;

    my $exe  = $Config::Config{_exe};
    unless ($cc) {
        warn "No compiler found, won't generate 'script/parl$exe'!\n";
    }


    makemaker_args(
        MAN1PODS		=> {
            'script/par.pl'	=> 'blib/man1/par.pl.1',
            'script/pp'	        => 'blib/man1/pp.1',
            'script/tkpp'       => 'blib/man1/tkpp.1',
          $cc ? (
            'script/parl.pod'   => 'blib/man1/parl.1',
          ) : (),
        },
        EXE_FILES		=> [
            'script/par.pl',
            'script/pp',
            'script/tkpp',
        ],
        DIR                     => [
          $cc ? (
            'myldr'
          ) : (),
        ],
        NEEDS_LINKING	        => $cc,
    );
}

WriteAll sign => 0;

