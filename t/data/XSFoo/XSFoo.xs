#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/*#include "ppport.h" */


MODULE = XSFoo		PACKAGE = XSFoo		

PROTOTYPES: DISABLE

void
hello()
    CODE:
        printf("greetings from XSFoo\n");
