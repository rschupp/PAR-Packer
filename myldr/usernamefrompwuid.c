#include "usernamefrompwuid.h"
#ifdef I_PWD
#  include <sys/types.h>
#  include <pwd.h>
#endif

/* This piece of code uses getpwuid from pwd.h to determine the current
 * use name.
 * Since pwd.h might not be available and perl's configure script probed
 * for this, we require access to perl's config.h. Whether or not we have that
 * can be determined by the Makefile.PL in myldr/. It writes the
 * usernamefrompwuid.h file for us. In the header, we include config.h if
 * available or sets I_PWD to undefined.
 * -- Steffen Mueller
 */

char *get_username_from_getpwuid () {
#ifdef I_PWD
    char *username = NULL;
    struct passwd *userdata = NULL;
    uid_t uid;
    uid = getuid();
    if (uid) {
        userdata = getpwuid(uid);
        username = userdata->pw_name;
    }
#else
    char *username = NULL;
#endif
    return(username);
}
