#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

int triple(int n) { return 3*n; }

MODULE = XSQuux  PACKAGE = XSQuux
PROTOTYPES: DISABLE

void
hello()
    CODE:
        printf("hello from XSQuux");
