#line 1
package parent;
use strict;
use vars qw($VERSION);
$VERSION = '0.223';

sub import {
    my $class = shift;

    my $inheritor = caller(0);

    if ( @_ and $_[0] eq '-norequire' ) {
        shift @_;
    } else {
        for ( my @filename = @_ ) {
            if ( $_ eq $inheritor ) {
                warn "Class '$inheritor' tried to inherit from itself\n";
            };

            s{::|'}{/}g;
            require "$_.pm"; # dies if the file is not found
        }
    }

    {
        no strict 'refs';
        # This is more efficient than push for the new MRO
        # at least until the new MRO is fixed
        @{"$inheritor\::ISA"} = (@{"$inheritor\::ISA"} , @_);
    };
};

"All your base are belong to us"

__END__

#line 136
