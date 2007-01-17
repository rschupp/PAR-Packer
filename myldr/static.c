#undef PL_statbuf
#undef readdir

#include "mktmpdir.c"
#include "my_perl.c"
#include "my_par.c"

/*
extern char * name_load_me_0;
extern char * name_load_me_1;
extern unsigned long size_load_me_0;
extern unsigned long size_load_me_1;
extern char load_me_0[];
extern char load_me_1[];
*/

char *my_file = NULL;
int  my_size = 0;

int my_mkfile (char* argv0, char* stmpdir, const char* name, unsigned long size) {
    int i;
#ifndef PL_statbuf
    struct stat PL_statbuf;
#endif

    my_size = strlen(stmpdir) + strlen(name) + 5;
    my_file = (char *)malloc( my_size );
    sprintf(my_file, "%s/%s", stmpdir, name);

    if ( par_lstat(my_file, &PL_statbuf) == 0 ) {
        if ( (unsigned long)PL_statbuf.st_size == size ) return -2;
    }

    i = open(my_file, O_CREAT | O_WRONLY | OPEN_O_BINARY);

    if (i == -1) {
        fprintf(stderr, "%s: creation of %s failed - aborting with %i.\n", argv0, my_file, errno);
        return 0;
    }

    return i;
}

int main ( int argc, char **argv, char **env )
{
    int i;
    char *stmpdir;
    char *buf = (char *)malloc(MAXPATHLEN);
#ifdef WIN32
typedef BOOL (WINAPI *pALLOW)(DWORD);
    HINSTANCE hinstLib;
    pALLOW ProcAdd;
#ifndef ASFW_ANY
#define ASFW_ANY -1
#endif
#endif

    par_init_env();
    par_mktmpdir( argv );

    stmpdir = (char *)par_getenv("PAR_TEMP");
    if ( stmpdir != NULL ) {
        i = my_mkdir(stmpdir, 0755);
        if ( (i != 0) && (i != EEXIST) && (i != -1) ) {
            fprintf(stderr, "%s: creation of private temporary subdirectory %s failed - aborting with %i.\n", argv[0], stmpdir, errno);
            return 2;
        }
    }

    i = my_mkfile( argv[0], stmpdir, name_load_me_0, size_load_me_0 );
    if ( !i ) return 2;
    if ( i != -2 ) {
        WRITE_load_me_0(i);
        close(i); chmod(my_file, 0755);
    }

    my_file = par_basename(par_findprog(argv[0], strdup(par_getenv("PATH"))));

    i = my_mkfile( argv[0], stmpdir, my_file, size_load_me_1 );
    if ( !i ) return 2;
    if ( i != -2 ) {
        WRITE_load_me_1(i);
        close(i); chmod(my_file, 0755);
    }

    sprintf(buf, "%i", argc);
    par_setenv("PAR_ARGC", buf);
    for (i = 0; i < argc; i++) {
        buf = (char *)malloc(strlen(argv[i]) + 14);
        sprintf(buf, "PAR_ARGV_%i", i);
        par_unsetenv(buf);
        par_setenv(buf, argv[i]);
    }

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
    i = spawnvpe(P_WAIT, my_file, (const char* const*)argv, (const char* const*)environ);
#else
    execvp(my_file, argv);
    return 2;
#endif

    par_cleanup(stmpdir);
    return i;
}
