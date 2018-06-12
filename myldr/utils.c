/*
 * Copyright (c) 1997 Todd C. Miller <Todd.Miller@courtesan.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

#ifdef WIN32
#  include <io.h>
#else
#  include <fcntl.h>
#endif
#include <stdio.h>

#include "env.c"


#if defined __linux__ || defined __FreeBSD__

/*  Look at /proc/$$/{exe,file} for the current executable 

    Returns malloc()ed string.  Caller must free.
    Returns NULL if can't be found.
    
    Note that FreeBSD has /proc unmounted by default.  You'd think we could
    get this info via the kvm interface, but it turns out that to get
    kvm_getprocs()/kvm_read() to return any information we don't already
    have, we need read-access to /boot/kmem, which we don't have.  And I
    couldn't get to work anyway.  Email me (philip-at-pied.nu) if want a
    stab at the code. */

char *par_current_exec_proc( void ) 
{
    char proc_path[MAXPATHLEN + 1], link[MAXPATHLEN + 1];
    char *ret = NULL;
    int n;
    
    n = sprintf( proc_path, "/proc/%i/%s", (int)getpid(), 
#if defined __FreeBSD__
        "file"
#else
        "exe"
#endif
    );
    if( n < 0 ) 
        return NULL;

    n = readlink( proc_path, link, MAXPATHLEN);
    if( n < 0 )
        return NULL;
    
    ret = (char *)malloc( n+1 );
    if( ret == NULL )
        return NULL;

    memcpy( ret, link, n );
    ret[n] = '\0';

    return ret;
} 

#endif

char *par_current_exec( void )
{
#if defined __linux__ || defined __FreeBSD__
    return par_current_exec_proc();
#else
    return NULL;
#endif
}



char *par_findprog(char *prog, char *path) {
    char *p, filename[MAXPATHLEN];
    /* char *ret; */ /* Commented out for reason described below */
    int proglen, plen;
    char *par_temp = par_getenv("PAR_TEMP");

    /* NOTE: This code is #include'd both from a plain C program (boot.c)
     * and our custom Perl interpreter (main.c). In the latter case,
     * lstat() or stat() may be #define'd as calls into PerlIO and
     * expect pointer to a Stat_t as second parameter, rather than a pointer
     * to a struct stat. Try to distinguish these cases by checking
     * whether Stat_t is defined. */
#ifndef Stat_t
#define Stat_t struct stat
#endif
    Stat_t statbuf;

#ifdef WIN32
    if ( GetModuleFileName(0, filename, MAXPATHLEN) ) {
        par_setenv("PAR_PROGNAME", filename);
        return strdup(filename);
    }
#endif

    /* Special case if prog contains '/' */
    if (strstr(prog, dir_sep)) {
        par_setenv("PAR_PROGNAME", prog);
        return(prog);
    }

    /* I'm commenting out this block because using par_current_exec_proc()
     * ends up breaking the PAR feature of inferring the script-to-be-run
     * from the name of the executable in case of symlinks because /proc/
     * has the name of the executable and not that of the symlink.
     */
/*
  #if defined __linux__ || defined __FreeBSD__
    ret = par_current_exec_proc();
  #else
    ret = NULL;
  #endif

    if( ret != NULL ) {
        par_setenv( "PAR_PROGNAME", ret );
        return ret;
    }
*/

    /* Walk through PATH (path), looking for ourself (prog).
        This fails if we are invoked in an obscure manner;
        Basically, execvp( "/full/path/to/prog", "prog", NULL ) and
        "/full/path/to" isn't in $PATH.  Of course, I can't think 
        of a situation this will happen. */
    proglen = strlen(prog);
    p = strtok(path, path_sep);
    while ( p != NULL ) {
        if (*p == '\0') p = ".";

        if ( par_temp != NULL && ( strcmp(par_temp, p) == 0 ) ) {
            p = strtok(NULL, path_sep);
            continue;
        }

        plen = strlen(p);

        /* strip trailing '/' */
        while (p[plen-1] == *dir_sep) {
            p[--plen] = '\0';
        }

        if (plen + 1 + proglen >= MAXPATHLEN) {
            par_setenv("PAR_PROGNAME", prog);
            return(prog);
        }

        sprintf(filename, "%s%s%s", p, dir_sep, prog);
        if ((stat(filename, &statbuf) == 0) && S_ISREG(statbuf.st_mode) &&
            access(filename, X_OK) == 0) {
                par_setenv("PAR_PROGNAME", filename);
                return(strdup(filename));
        }
        p = strtok(NULL, path_sep);
    }

    par_setenv("PAR_PROGNAME", prog);
    return(prog);
}


char *par_basename (const char *name) {
    const char *base = name;
    const char *p;

    for (p = name; *p; p++) {
        if (*p == *dir_sep) base = p + 1;
    }

    return (char *)base;
}




char *par_dirname (const char *path) {
    static char bname[MAXPATHLEN];
    register const char *endp;

    /* Empty or NULL string gets treated as "." */
    if (path == NULL || *path == '\0') {
        return(strdup("."));
    }

    /* Strip trailing slashes */
    endp = path + strlen(path) - 1;
    while (endp > path && *endp == *dir_sep) endp--;

    /* Find the start of the dir */
    while (endp > path && *endp != *dir_sep) endp--;

    /* Either the dir is "/" or there are no slashes */
    if (endp == path) {
        if (*endp == *dir_sep) {
            return strdup(".");
        }
        else {
            return strdup(dir_sep);
        }
    } else {
        do {
            endp--;
        } while (endp > path && *endp == *dir_sep);
    }

    if (endp - path + 2 > sizeof(bname)) {
        return(NULL);
    }

    strncpy(bname, path, endp - path + 1);
    return(bname);
}

void par_init_env () {
    char par_clean[] = "__ENV_PAR_CLEAN__               \0";
    char *buf;

    /* ignore PERL5LIB et al. as they make no sense for a self-contained executable */
    par_unsetenv("PERL5LIB");
    par_unsetenv("PERLLIB");
    par_unsetenv("PERL5OPT");
    par_unsetenv("PERLIO");

    par_unsetenv("PAR_INITIALIZED");
    par_unsetenv("PAR_SPAWNED");
    par_unsetenv("PAR_TEMP");
    par_unsetenv("PAR_CLEAN");
    par_unsetenv("PAR_DEBUG");
    par_unsetenv("PAR_CACHE");
    par_unsetenv("PAR_PROGNAME");

    if ( (buf = par_getenv("PAR_GLOBAL_DEBUG")) != NULL ) {
        par_setenv("PAR_DEBUG", buf);
    }

    if ( (buf = par_getenv("PAR_GLOBAL_TMPDIR")) != NULL ) {
        par_setenv("PAR_TMPDIR", buf);
    }

    if ( (buf = par_getenv("PAR_GLOBAL_TEMP")) != NULL ) {
        par_setenv("PAR_TEMP", buf);
    }
    else if ( (buf = par_getenv("PAR_GLOBAL_CLEAN")) != NULL ) {
        par_setenv("PAR_CLEAN", buf);
    }
    else {
        buf = par_clean + 12 + strlen("CLEAN");
        if (strncmp(buf, "PAR_CLEAN=", strlen("PAR_CLEAN=")) == 0) {
            par_setenv("PAR_CLEAN", buf + strlen("PAR_CLEAN="));
        }
    }

    par_setenv("PAR_INITIALIZED", "1");

    return;
}

int par_env_clean () {
    static int rv = -1;

    if (rv == -1) {
        char *buf = par_getenv("PAR_CLEAN");
        rv = ( ((buf == NULL) || (*buf == '\0') || (*buf == '0')) ? 0 : 1);
    }

    return rv;
}
