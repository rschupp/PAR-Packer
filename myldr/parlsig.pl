use strict;

my ($parl_exe, $par_exe, $dynperl, $chunk_size) = @ARGV;
exit unless $dynperl;

local $/;
open _FH, $par_exe or die $!;
binmode _FH;
my $input_exe = <_FH>;
close _FH;
open _FH, $parl_exe or die $!;
binmode _FH;
my $output_exe = <_FH>;
close _FH;
my $offset = rindex($output_exe, substr($input_exe, 0, $chunk_size));
die "Impossible: Can't find $par_exe inside $parl_exe" if $offset == -1;
open _FH, '>>', $parl_exe or die $!;
binmode _FH;
print _FH pack('N', $offset);
close _FH;
