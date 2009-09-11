#line 1
package PerlIO;

our $VERSION = '1.04';

# Map layer name to package that defines it
our %alias;

sub import
{
 my $class = shift;
 while (@_)
  {
   my $layer = shift;
   if (exists $alias{$layer})
    {
     $layer = $alias{$layer}
    }
   else
    {
     $layer = "${class}::$layer";
    }
   eval "require $layer";
   warn $@ if $@;
  }
}

sub F_UTF8 () { 0x8000 }

1;
__END__

#line 344
