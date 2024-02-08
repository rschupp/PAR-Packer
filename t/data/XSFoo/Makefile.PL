use 5.008009;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'XSFoo',
    VERSION           => '0.01',
    PREREQ_PM         => {},
    ABSTRACT          => 'Test files for PAR::Packer',
    AUTHOR            => 'Roderich Schupp <roderich.schupp@gmail.com>',
    LICENSE           => 'perl',
    LIBS              => [''],
    DEFINE            => '',
    INC               => '-I.',
);
