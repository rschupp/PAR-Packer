use 5.008009;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'XSFoo',
    VERSION_FROM      => 'lib/XSFoo.pm',
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ABSTRACT          => 'Test PAR::PAcker with XS modules',
    AUTHOR            => 'Roderich Schupp <rschupp@cpan.org>',
    LICENSE           => 'perl',
    LIBS              => [''], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => '-I.', # e.g., '-I. -I/usr/include/other'
    # OBJECT            => '$(O_FILES)', # link all the C files too
);
