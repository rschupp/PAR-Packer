#undef readdir

#ifdef _MSC_VER
#include <io.h>
#else
#include <sys/types.h>
#include <unistd.h>
#endif

typedef struct my_chunk
{
    int len;
    unsigned char *buf;
} my_chunk;

/* returns 0 if OK, -1 if error */
static 
int write_chunks(int fd, my_chunk *chunks) {
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

/* Note: these two defines must be negative so as not to collide with 
 * any real file descriptor */
#define MKFILE_ERROR          (-1)
#define MKFILE_ALREADY_EXISTS (-2)

static 
int my_mkfile (char* argv0, char* stmpdir, const char* name, off_t expected_size, char** file_p) {
    int i;
    struct stat statbuf;

    *file_p = malloc(strlen(stmpdir) + 1 + strlen(name) + 1);
    sprintf(*file_p, "%s/%s", stmpdir, name);


    i = open(*file_p, O_CREAT | O_EXCL | O_WRONLY | OPEN_O_BINARY, 0755);
    if ( i != -1 ) 
        return i;

    if ( errno == EEXIST 
         && par_lstat(*file_p, &statbuf) == 0 
         && statbuf.st_size == expected_size )
	return MKFILE_ALREADY_EXISTS;

    fprintf(stderr, "%s: creation of %s failed (errno=%i)\n", argv0, *file_p, errno);
    return MKFILE_ERROR;
}


/* turn off automatic globbing of process arguments when using MingW */
#if defined(WIN32) && defined(__MINGW32__)
int _CRT_glob = 0;
#endif

#ifdef WIN32
#define unpack_S(p) (*(WORD*)(p))
#define unpack_L(p) (*(DWORD*)(p))

#define ASSERT(expr, msg) if (!(expr)) fprintf(stderr, "assertion failed: %s\n", msg)

/* seek file descriptor fd to member Subsystem (a WORD) of the
 * IMAGE_OPTIONAL_HEADER structure of a Windows executable
 * (so that the next 2 bytes read/written from/to fd get/set Subsystem);
 * cf. sub _fix_console in PAR/Packer.pm 
 */
void seek_to_subsystem( int fd ) {
    BYTE buf[64];
    DWORD off;
    WORD size, magic;

    lseek(fd, 0, SEEK_SET);              // CHECK != -1
    read(fd, buf, 64);                  // CHECK == 64
    ASSERT(unpack_S(buf) == 0x5a4d, "MZ magic bytes");    // "MZ"
    off = unpack_L(buf+60);

    lseek(fd, off, SEEK_SET);                // CHECK != -1
    read(fd, buf, 4 + 20 + 2);         // CHECK == 4 + 20 + 2
    ASSERT(unpack_L(buf) == 0x4550, "PE header");    // "PE\0\0"
    size = unpack_S(buf+20);
    magic = unpack_S(buf+24);
    ASSERT(( size == 224 && magic == 0x10b ) 
           || ( size == 240 && magic == 0x20b ), "IMAGE_NT_OPTIONAL_HDR_MAGIC");

    lseek(fd, off + 4 + 20 + 68, SEEK_SET);          // CHECK != -1
}
#endif


int main ( int argc, char **argv, char **env )
{
    int i;
    char *stmpdir;
    char *my_file;
    char *my_perl;
    char *my_prog;
    char buf[20];	/* must be large enough to hold "PAR_ARGV_###" */
#ifdef WIN32
typedef BOOL (WINAPI *pALLOW)(DWORD);
    HINSTANCE hinstLib;
    pALLOW ProcAdd;
#ifndef ASFW_ANY
#define ASFW_ANY -1
#endif
#endif

#define DIE exit(255)

    par_init_env();

    stmpdir = par_mktmpdir( argv );	
    if ( !stmpdir ) DIE;        /* error message has already been printed */

    i = my_mkdir(stmpdir, 0700);
    if ( i == -1 && errno != EEXIST) {
	fprintf(stderr, "%s: creation of private cache subdirectory %s failed (errno= %i)\n", argv[0], stmpdir, errno);
 	DIE;
    }

    /* extract custom Perl interpreter into stmpdir 
       (but under the same basename as argv[0]) */
    my_prog = par_findprog(argv[0], strdup(par_getenv("PATH")));
    i = my_mkfile( argv[0], stmpdir, par_basename(my_prog), size_load_my_par, &my_perl );
    if ( i != MKFILE_ALREADY_EXISTS ) {
        if ( i == MKFILE_ERROR ) DIE;
        if ( write_chunks(i, chunks_load_my_par) == -1 ) DIE;
        if ( close(i) == -1 ) DIE;
        chmod(my_perl, 0755);

#ifdef __hpux
        {
            /* HPUX will only honour SHLIB_PATH if the executable is specially marked */
            char *chatr_cmd = malloc(strlen(my_perl) + 200);
            sprintf(chatr_cmd, "/usr/bin/chatr +s enable %s > /dev/null", my_perl);
            system(chatr_cmd);
        }
#endif
#ifdef WIN32
        {
            /* copy IMAGE_OPTIONAL_HEADER.Subsystem  (GUI vs console)
             * from this executable to the just extracted my_perl
             */
            int fd;
            WORD subsystem;

            fd = open(my_prog, O_RDONLY | OPEN_O_BINARY, 0755);
            ASSERT(fd != -1, "open my_prog");
            seek_to_subsystem(fd);
            read(fd, &subsystem, 2);    // CHECK == 2
            close(fd);                  // CHECK != -1

            fd = open(my_perl, O_RDWR | OPEN_O_BINARY, 0755);
            ASSERT(fd != -1, "open my_perl");
            seek_to_subsystem(fd);
            write(fd, &subsystem, 2);   // CHECK == 2
            close(fd);                  // CHECK != -1
        }
#endif
    }

    /* extract libperl DLL into stmpdir */
    i = my_mkfile( argv[0], stmpdir, name_load_my_libperl, size_load_my_libperl, &my_file );
    if ( i != MKFILE_ALREADY_EXISTS ) {
        if ( i == MKFILE_ERROR ) DIE;
        if ( write_chunks(i, chunks_load_my_libperl) == -1 ) DIE;
        if ( close(i) == -1 ) DIE;
        chmod(my_file, 0755);
    }

#ifdef LOAD_MY_LIBGCC
    /* extract libgcc DLL into stmpdir */
    i = my_mkfile( argv[0], stmpdir, name_load_my_libgcc, size_load_my_libgcc, &my_file );
    if ( i != MKFILE_ALREADY_EXISTS ) {
        if ( i == MKFILE_ERROR ) DIE;
        if ( write_chunks(i, chunks_load_my_libgcc) == -1 ) DIE;
        if ( close(i) == -1 ) DIE;
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

    par_cleanup(stmpdir);
    exit(i);
#else
    execvp(my_perl, argv);
    DIE;
#endif
}

