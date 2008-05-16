#include "usernamefrompwuid.h"
#ifdef I_PWD
#  include <sys/types.h>
#  include <pwd.h>
#endif

/* This piece of code uses getpwuid from pwd.h to determine the current
 * user name.
 * Since pwd.h might not be available and perl's configure script probed
 * for this, we require access to perl's config.h. Whether or not we have that
 * can be determined by the Makefile.PL in myldr/. It writes the
 * usernamefrompwuid.h file for us. In the header, we include config.h if
 * available or sets I_PWD to undefined.
 * -- Steffen Mueller
 */

char *get_username_from_getpwuid () {
    char *username = NULL;
#ifdef I_PWD
    struct passwd *userdata = NULL;
    userdata = getpwuid(getuid());
    if (userdata)
        username = userdata->pw_name;
#endif
    return(username);
}
