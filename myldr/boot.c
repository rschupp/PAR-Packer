#undef readdir

#include <unistd.h>

typedef struct my_chunk
{
    int len;
    unsigned char *buf;
} my_chunk;

/* returns 0 if OK, -1 if error */
int write_chunks(my_chunk *chunks, int fd) {
    while (chunks->len) {
	if ( write(fd, chunks->buf, chunks->len) != chunks->len )
	    return -1;
	chunks++;
    }
    return 0;
}

#include "mktmpdir.c"
#include "my_par.c"
#include "my_libperl.c"
#ifdef LOAD_MY_LIBGCC
#include "my_libgcc.c"
#endif

int my_mkfile (char* argv0, char* stmpdir, const char* name, off_t expected_size, char** file_p) {
    int i;
    struct stat statbuf;

    *file_p = malloc(strlen(stmpdir) + 1 + strlen(name) + 1);
    sprintf(*file_p, "%s/%s", stmpdir, name);

    if ( par_lstat(*file_p, &statbuf) == 0 
         && statbuf.st_size == expected_size )
	return -2;

    i = open(*file_p, O_CREAT | O_WRONLY | OPEN_O_BINARY, 0755);

    if (i == -1) {
        fprintf(stderr, "%s: creation of %s failed - aborting with errno %i.\n", argv0, *file_p, errno);
        return 0;
    }

    return i;
}


/* turn off automatic globbing of process arguments when using MingW */
#if defined(WIN32) && defined(__MINGW32__)
int _CRT_glob = 0;
#endif

int main ( int argc, char **argv, char **env )
{
    int i;
    char *stmpdir;
    char *my_file;
    char *my_perl;
    char buf[20];	/* must be large enough to hold "PAR_ARGV_###" */
#ifdef WIN32
typedef BOOL (WINAPI *pALLOW)(DWORD);
    HINSTANCE hinstLib;
    pALLOW ProcAdd;
#ifndef ASFW_ANY
#define ASFW_ANY -1
#endif
#endif

    par_init_env();

    stmpdir = par_mktmpdir( argv );	
    i = my_mkdir(stmpdir, 0755);
    if ( i == -1 && errno != EEXIST) {
	fprintf(stderr, "%s: creation of private temporary subdirectory %s failed - aborting with errno %i.\n", argv[0], stmpdir, errno);
	return 2;
    }

    /* extract custom Perl interpreter into stmpdir 
       (but under the same basename as argv[0]) */
    i = my_mkfile( argv[0], 
	           stmpdir, par_basename(par_findprog(argv[0], strdup(par_getenv("PATH")))),
	           size_load_my_par, &my_perl );
    if ( !i ) return 2;
    if ( i != -2 ) {
        if (write_chunks(chunks_load_my_par, i) || close(i))
	    return 2;
        close(i); 
        chmod(my_perl, 0755);
#ifdef __hpux
        {
            /* HPUX will only honour SHLIB_PATH if the executable is specially marked */
            char *chatr_cmd = malloc(strlen(my_perl) + 200);
            sprintf(chatr_cmd, "/usr/bin/chatr +s enable %s > /dev/null", my_perl);
            system(chatr_cmd);
        }
#endif
    }

    /* extract libperl DLL into stmpdir */
    i = my_mkfile( argv[0], stmpdir, name_load_my_libperl, size_load_my_libperl, &my_file );
    if ( !i ) return 2;
    if ( i != -2 ) {
        if (write_chunks(chunks_load_my_libperl, i) || close(i))
	    return 2;
        chmod(my_file, 0755);
    }

#ifdef LOAD_MY_LIBGCC
    /* extract libgcc DLL into stmpdir */
    i = my_mkfile( argv[0], stmpdir, name_load_my_libgcc, size_load_my_libgcc, &my_file );
    if ( !i ) return 2;
    if ( i != -2 ) {
        if (write_chunks(chunks_load_my_libgcc, i) || close(i))
	    return 2;
        chmod(my_file, 0755);
    }

#endif

    /* save original argv[] into environment variables PAR_ARGV_# */
    sprintf(buf, "%i", argc);
    par_setenv("PAR_ARGC", buf);
    for (i = 0; i < argc; i++) {
        sprintf(buf, "PAR_ARGV_%i", i);
        par_unsetenv(buf);
        par_setenv(buf, argv[i]);
    }

    /* finally spawn the custom Perl interpreter */
#ifdef WIN32
    hinstLib = LoadLibrary("user32");
    if (hinstLib != NULL) {
        ProcAdd = (pALLOW) GetProcAddress(hinstLib, "AllowSetForegroundWindow");
        if (ProcAdd != NULL)
        {
            (ProcAdd)(ASFW_ANY);
        }
    }

    par_setenv("PAR_SPAWNED", "1");
    i = spawnvpe(P_WAIT, my_perl, (const char* const*)argv, (const char* const*)environ);
#else
    execvp(my_perl, argv);
    return 2;
#endif

    par_cleanup(stmpdir);
    return i;
}
