#!/usr/bin/perl
use strict;
use warnings;

use ExtUtils::MakeMaker;
use ExtUtils::CBuilder;

if ($] == 5.010000) {
    # 5.10.0 breaks how PAR intercepts loading of shared libraries
    warn <<'...';
*** Perl version 5.10.0 is not supported.
    Please upgrade to 5.10.1 or better.
...
    exit 0;
}

sub if_win { return ($^O eq 'MSWin32') ? @_ : (); }

my $have_cc = ExtUtils::CBuilder->new->have_compiler;
warn "No compiler found, won't generate 'script/parl$Config::Config{_exe}!\n"
    unless $have_cc;

WriteMakefile1(

    NAME                      => 'PAR::Packer',
    VERSION_FROM              => 'lib/PAR/Packer.pm',
    ABSTRACT_FROM             => 'lib/PAR/Packer.pm',
    LICENSE                   => 'perl_5',
    AUTHOR                    => [ 'Audrey Tang <cpan@audreyt.org>' ],

    MIN_PERL_VERSION          => '5.008009',

    CONFIGURE_REQUIRES => {
      'ExtUtils::Embed'       => 0,
      'ExtUtils::CBuilder'    => 0,
      'DynaLoader'            => 0,
      'File::Basename'        => 0,
      'File::Glob'            => 0,
      'File::Spec::Functions' => 0,
    },
    PREREQ_PM => {
      'File::Temp'            => '0.05',
      'Compress::Zlib'        => ($^O eq 'MSWin32') ? '1.16' : '1.30',
      'IO::Compress::Gzip'    => 0,
      'Archive::Zip'          => '1.02',
      'Module::ScanDeps'      => '1.21',
      'PAR::Dist'             => '0.22',
      'PAR'                   => '1.016',
      'Digest::SHA'           => '5.40',
      'Text::ParseWords'      => 0,
      'Getopt::ArgvFile'      => '1.07',
    },
    TEST_REQUIRES => {
      'Test::More'            => 0,
      'IPC::Run3'             => '0.048',
      if_win(
        'Win32::Exe'          => '0.17'),
    },

    MAN1PODS => {
      'script/par.pl'         => 'blib/man1/par.pl.1',
      'script/pp'             => 'blib/man1/pp.1',
      'script/tkpp'           => 'blib/man1/tkpp.1',
      $have_cc ? (
        'script/parl.pod'     => 'blib/man1/parl.1' ) : (),
    },
    EXE_FILES		=> [
        'script/par.pl',
        'script/pp',
        'script/tkpp',
    ],
    DIR                       => $have_cc ? [ 'myldr' ] : [],
    NEEDS_LINKING	      => $have_cc,

    META_MERGE      => {
      'meta-spec'             => { version => 2 },
      prereqs => {
        runtime => {
          recommends => {
            # for digital signature support
            'Digest'          => 0,
            'Module::Signature' => 0,
            # for tkpp
            'Tk'              => 0,
            'Tk::ColoredButton' => 0,
            'Tk::EntryCheck'  => 0,
            'Tk::Getopt'      => 0,
            if_win(
              'Win32::Process' => 0),
          },
        },
      },
      resources          => {
        repository  => {
          type => 'git',
          url  => 'git://github.com/rschupp/PAR-Packer.git',
          web  => 'https://github.com/rschupp/PAR-Packer',
        },
        MailingList => 'mailto:par@perl.org',
        bugtracker => { web => 'https://github.com/rschupp/PAR-Packer/issues' },
      },
      no_index => {
        directory => [ 'contrib' ],
      },
    },
);

# inhibit parallel make as modules must be installed into blib *before*
# recursing into myldr (i.e. target pm_to_blib must have finished
# before subdirs is started)
sub MY::postamble
{
    return <<'...'
# GNU make and others
.NOTPARALLEL:
# dmake
.SEQUENTIAL:
...
}

sub WriteMakefile1 {  #Compatibility code for old versions of EU::MM. Written by Alexandr Ciornii, version 2. Added by eumm-upgrade.
    my %params=@_;
    my $eumm_version=$ExtUtils::MakeMaker::VERSION;
    $eumm_version=eval $eumm_version;
    die "EXTRA_META is deprecated" if exists $params{EXTRA_META};
    die "License not specified" if not exists $params{LICENSE};
    if ($params{AUTHOR} and ref($params{AUTHOR}) eq 'ARRAY' and $eumm_version < 6.5705) {
        $params{META_ADD}->{author}=$params{AUTHOR};
        $params{AUTHOR}=join(', ',@{$params{AUTHOR}});
    }
    if ($params{TEST_REQUIRES} and $eumm_version < 6.64) {
        $params{BUILD_REQUIRES}={ %{$params{BUILD_REQUIRES} || {}} , %{$params{TEST_REQUIRES}} };
        delete $params{TEST_REQUIRES};
    }
    if ($params{BUILD_REQUIRES} and $eumm_version < 6.5503) {
        #EUMM 6.5502 has problems with BUILD_REQUIRES
        $params{PREREQ_PM}={ %{$params{PREREQ_PM} || {}} , %{$params{BUILD_REQUIRES}} };
        delete $params{BUILD_REQUIRES};
    }
    delete $params{CONFIGURE_REQUIRES} if $eumm_version < 6.52;
    delete $params{MIN_PERL_VERSION} if $eumm_version < 6.48;
    delete $params{META_MERGE} if $eumm_version < 6.46;
    delete $params{META_ADD} if $eumm_version < 6.46;
    delete $params{LICENSE} if $eumm_version < 6.31;

    WriteMakefile(%params);
}

