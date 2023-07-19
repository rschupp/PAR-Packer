requires 'Archive::Zip', '1.02';
requires 'Compress::Zlib', '1.30';
requires 'Digest::SHA', '5.40';
requires 'File::Temp', '0.05';
requires 'Getopt::ArgvFile', '1.07';
requires 'IO::Compress::Gzip';
requires 'Module::ScanDeps', '1.21';
requires 'PAR', '1.016';
requires 'PAR::Dist', '0.22';
requires 'Text::ParseWords';
requires 'perl', '5.008009';

recommends 'Digest';
recommends 'Module::Signature';
recommends 'Tk';
recommends 'Tk::ColoredButton';
recommends 'Tk::EntryCheck';
recommends 'Tk::Getopt';

on configure => sub {
    requires 'DynaLoader';
    requires 'ExtUtils::CBuilder';
    requires 'ExtUtils::Embed';
    requires 'File::Basename';
    requires 'File::Glob';
    requires 'File::Spec::Functions';
};

on build => sub {
    requires 'ExtUtils::MakeMaker';
};

on test => sub {
    requires 'IPC::Run3', '0.048';
    requires 'Test::More';
};
