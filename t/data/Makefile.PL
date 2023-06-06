use 5.008009;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'XSFoo',
    VERSION_FROM      => 'lib/XSFoo.pm',
    PREREQ_PM         => {},
    ABSTRACT          => 'Test files for PAR::Packer',
    AUTHOR            => 'Roderich Schupp <rschupp@cpan.org>',
    LICENSE           => 'perl',
    LIBS              => [''],
    DEFINE            => '',
    INC               => '-I.',

    INST_ARCHLIB      => '$(INST_LIB)',
    clean             => { FILES => '../blib' },
);
