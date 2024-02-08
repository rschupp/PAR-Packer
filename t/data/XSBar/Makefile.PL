use 5.008009;   # should match MIN_PERL_VERSION in toplevel Makefile.PL
use ExtUtils::MakeMaker;
use ExtUtils::Depends;

my $pkg = ExtUtils::Depends->new(qw(XSBar XSQuux));
$pkg->add_xs(qw(XSBar.xs));
$pkg->add_pm('XSBar.pm' => '$(INST_LIB)/XSBar.pm');
$pkg->save_config("Files.pm");

WriteMakefile(
    NAME              => 'XSBar',
    VERSION           => '0.01',
    PREREQ_PM         => {},
    ABSTRACT          => 'simple XS module',
    AUTHOR            => 'roderich <roderich@>',
    $pkg->get_makefile_vars(),
    clean             => { FILES => "Files.pm" },       # must come after get_makefile_vars
);
