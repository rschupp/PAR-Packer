#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

extern int triple(int);

MODULE = XSBar  PACKAGE = XSBar	
PROTOTYPES: DISABLE

void
hello()
    CODE:
        printf("hello from XSBar");

void
calling_into_quux(int i)
    CODE:
        printf("calling into quux...\n");
        printf("triple(%i) = %i", i, triple(i));
