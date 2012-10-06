#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "perlxsi.c"

#include "my_par_pl.c"

/* Workaround for mapstart: the only op which needs a different ppaddr */
#undef Perl_pp_mapstart
#define Perl_pp_mapstart Perl_pp_grepstart
#undef OP_MAPSTART
#define OP_MAPSTART OP_GREPSTART

static PerlInterpreter *my_perl;

static char *stmpdir;
static int options_count;
static char **fakeargv;

#ifdef HAS_PROCSELFEXE
/* This is a function so that we don't hold on to MAXPATHLEN
   bytes of stack longer than necessary
 */
STATIC void
S_procself_val(pTHX_ SV *sv, char *arg0)
{
    char buf[MAXPATHLEN];
    int len = readlink(PROCSELFEXE_PATH, buf, sizeof(buf) - 1);

    /* On Playstation2 Linux V1.0 (kernel 2.2.1) readlink(/proc/self/exe)
       includes a spurious NUL which will cause $^X to fail in system
       or backticks (this will prevent extensions from being built and
       many tests from working). readlink is not meant to add a NUL.
       Normal readlink works fine.
     */
    if (len > 0 && buf[len-1] == '\0')
      len--;

    /* FreeBSD's implementation is acknowledged to be imperfect, sometimes
       returning the text "unknown" from the readlink rather than the path
       to the executable (or returning an error from the readlink).  Any valid
       path has a '/' in it somewhere, so use that to validate the result.
       See http://www.freebsd.org/cgi/query-pr.cgi?pr=35703
    */
    if (len > 0 && memchr(buf, '/', len))
        sv_setpvn(sv, buf, len);
    else
        sv_setpv(sv,arg0);
}
#endif /* HAS_PROCSELFEXE */

#include "mktmpdir.c"
#include "internals.c"

int main ( int argc, char **argv, char **env )
{
    int exitstatus;
    int i;
    int argno = 0;

#ifdef PERL_GPROF_MONCONTROL
    PERL_GPROF_MONCONTROL(0);
#endif
#ifdef PERL_SYS_INIT3
    PERL_SYS_INIT3(&argc, &argv, &env);
#endif

#if (defined(USE_5005THREADS) || defined(USE_ITHREADS)) && defined(HAS_PTHREAD_ATFORK)
    /* XXX Ideally, this should really be happening in perl_alloc() or
     * perl_construct() to keep libperl.a transparently fork()-safe.
     * It is currently done here only because Apache/mod_perl have
     * problems due to lack of a call to cancel pthread_atfork()
     * handlers when shared objects that contain the handlers may
     * be dlclose()d.  This forces applications that embed perl to
     * call PTHREAD_ATFORK() explicitly, but if and only if it hasn't
     * been called at least once before in the current process.
     * --GSAR 2001-07-20 */
    PTHREAD_ATFORK(Perl_atfork_lock,
                   Perl_atfork_unlock,
                   Perl_atfork_unlock);
#endif

    if (!PL_do_undump) {
        my_perl = perl_alloc();
        if (!my_perl)
            exit(1);
        perl_construct( my_perl );
        PL_perl_destruct_level = 0;
    }
#ifdef PERL_EXIT_DESTRUCT_END
    PL_exit_flags |= PERL_EXIT_DESTRUCT_END;
#endif /* PERL_EXIT_DESTRUCT_END */
#ifdef PERL_EXIT_EXPECTED
    PL_exit_flags |= PERL_EXIT_EXPECTED;
#endif /* PERL_EXIT_EXPECTED */

#if (defined(CSH) && defined(PL_cshname))
    if (!PL_cshlen)
      PL_cshlen = strlen(PL_cshname);
#endif

#ifdef PERL_PROFILING
#define PROFILING_OPTION 1
#else
#define PROFILING_OPTION 0
#endif

#ifdef ALLOW_PERL_OPTIONS
#define EXTRA_OPTIONS 3
#else
#define EXTRA_OPTIONS 4
#endif /* ALLOW_PERL_OPTIONS */
    New(666, fakeargv, argc + EXTRA_OPTIONS + 1 + PROFILING_OPTION, char *);

    fakeargv[argno++] = argv[0];
#ifdef PERL_PROFILING
    fakeargv[argno++] = "-d:DProf";
#endif

    fakeargv[argno++] = "-e";
    fakeargv[argno++] = my_par_pl;

#ifndef ALLOW_PERL_OPTIONS
    fakeargv[argno++] = "--";
#endif /* ALLOW_PERL_OPTIONS */

    options_count = argno;

    for (i = 1; i < argc; i++)
        fakeargv[i + options_count - 1] = argv[i];
    fakeargv[argc + options_count - 1] = 0;

    exitstatus = perl_parse(my_perl, par_xs_init, argc + options_count - 1,
                            fakeargv, (char **)NULL);

    if (exitstatus == 0)
	exitstatus = perl_run( my_perl );

    perl_destruct( my_perl );

    if ( par_getenv("PAR_SPAWNED") == NULL ) {
        if ( stmpdir == NULL )
            stmpdir = par_getenv("PAR_TEMP");
        if ( stmpdir != NULL )
            par_cleanup(stmpdir);
    }

    perl_free( my_perl );
    PERL_SYS_TERM();

    return exitstatus;
}
