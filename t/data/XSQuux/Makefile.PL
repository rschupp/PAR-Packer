use 5.008009;   # should match MIN_PERL_VERSION in toplevel Makefile.PL
use ExtUtils::MakeMaker;
use ExtUtils::Depends;

my $pkg = ExtUtils::Depends->new(qw(XSQuux));
$pkg->add_xs(qw(XSQuux.xs));
$pkg->add_pm('XSQuux.pm' => '$(INST_LIB)/XSQuux.pm');
$pkg->save_config("Files.pm");

WriteMakefile(
    NAME              => 'XSQuux',
    VERSION           => '0.01',
    PREREQ_PM         => {},
    ABSTRACT          => 'simple XS module',
    AUTHOR            => 'roderich <roderich@>',
    FUNCLIST          => [qw( triple )],
    DL_FUNCS          => { XSQuux => [] },
    $pkg->get_makefile_vars(),
    clean             => { FILES => "Files.pm" },       # must come after get_makefile_vars
);
