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
#include <string.h>
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



char *par_findprog(char *prog, const char *path) {
    char *p, *endp, filename[MAXPATHLEN];
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
        return prog;
    }

    /* Walk through PATH (path), looking for ourself (prog).
        This fails if we are invoked in an obscure manner;
        Basically, execvp( "/full/path/to/prog", "prog", NULL ) and
        "/full/path/to" isn't in $PATH.  Of course, I can't think 
        of a situation this will happen. */

    /* Note: use a copy of path as strtok() modifies its first argument */
    for (p = strtok(strdup(path), path_sep); p != NULL;  p = strtok(NULL, path_sep))  {
        /* an empty PATH element means the current directory */
        if (*p == '\0') p = ".";

        if ( par_temp != NULL && ( strcmp(par_temp, p) == 0 ) ) {
            continue;
        }

        /* strip trailing '/' */
        endp = p + strlen(p) - 1;
        while (p < endp && *endp == *dir_sep) {
            *endp ='\0';
            endp--;
        }

        if (strlen(p) + strlen(dir_sep) + strlen(prog) + 1 < sizeof(filename)) {
            sprintf(filename, "%s%s%s", p, dir_sep, prog);
            if (stat(filename, &statbuf) == 0
                && S_ISREG(statbuf.st_mode)
                && access(filename, X_OK) == 0) {
                    par_setenv("PAR_PROGNAME", filename);
                    return strdup(filename);
            }
        }
    }

    par_setenv("PAR_PROGNAME", prog);
    return prog;
}


char *par_basename (const char *name) {
    char *base = strrchr(name, *dir_sep);
    return strdup(base != NULL ? base + 1 : name);
}


char *par_dirname (const char *path) {
    char dname[MAXPATHLEN];
    char *endp;

    /* Empty or NULL string gets treated as "." */
    if (path == NULL || *path == '\0') {
        return strdup(".");
    }

    if (strlen(path) + 1 > sizeof(dname))
        return NULL;

    strcpy(dname, path);

    /* Strip trailing slashes */
    endp = dname + strlen(dname) - 1;
    while (endp > dname && *endp == *dir_sep) {
        *endp = '\0';
        endp--;
    }

    endp = strrchr(dname, *dir_sep);
    if (endp == NULL)
        return strdup(".");
    if (endp > dname)
        *endp = '\0';
    return strdup(dname);
}


void par_init_env () {
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

    par_setenv("PAR_INITIALIZED", "1");

    return;
}

int par_env_clean () {
    char *val = par_getenv("PAR_CLEAN");
    if (val == NULL || *val == '\0' || *val == '0')
        return 0;
    return 1;
}

void par_die(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    vfprintf(stderr, format, ap);
    va_end(ap);
    
    exit(255);
}

