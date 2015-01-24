#undef readdir

#ifdef _MSC_VER
#include <io.h>
#else
#include <sys/types.h>
#include <unistd.h>
#endif

#include "mktmpdir.c"

typedef struct
{
    size_t len;
    unsigned char *buf;
} chunk_t;


typedef struct
{
    const char *name;
    size_t size;
    chunk_t *chunks;
} embedded_file_t;

#include "boot_embedded_files.c"

#define EXTRACT_FAIL    0
#define EXTRACT_OK      1
#define EXTRACT_ALREADY 2

/* extract EMB_FILE to file STMPDIR/EXT_NAME and set *EXT_PATH to the latter;
 * return EXTRACT_ALREADY if the extracted file already exists (and has the
 * expected size), EXTRACT_OK if successful, EXTRACT_FAIL otherwise
 */
static 
int extract_embedded_file(embedded_file_t *emb_file, const char* ext_name, const char* stmpdir, char** ext_path) {
    int fd;
    chunk_t *chunk;
    struct stat statbuf;

    *ext_path = malloc(strlen(stmpdir) + 1 + strlen(ext_name) + 1);
    sprintf(*ext_path, "%s/%s", stmpdir, ext_name);

    fd = open(*ext_path, O_CREAT | O_EXCL | O_WRONLY | OPEN_O_BINARY, 0755);
    if ( fd == -1 ) {
        if ( errno != EEXIST ) return EXTRACT_FAIL;

        if (par_lstat(*ext_path, &statbuf) == 0 
            && statbuf.st_size == emb_file->size )
            /* file already exists and has the expected size */
            return EXTRACT_ALREADY;           

        /* corrupted file? re-try writing it */
        fd = open(*ext_path, O_CREAT | O_WRONLY | OPEN_O_BINARY, 0755);
        if ( fd == -1 ) return EXTRACT_FAIL;
    }

    chunk = emb_file->chunks;
    while (chunk->len) {
        if ( write(fd, chunk->buf, chunk->len) != chunk->len ) {
            return 0;
        }
        chunk++;
    }
    if (close(fd) == -1)
        return EXTRACT_FAIL;

    chmod(*ext_path, 0750);
    return EXTRACT_OK;
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
    int rc, i;
    char *stmpdir;
    embedded_file_t *emb_file;
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

    rc = my_mkdir(stmpdir, 0700);
    if ( rc == -1 && errno != EEXIST) {
	fprintf(stderr, "%s: creation of private cache subdirectory %s failed (errno= %i)\n", 
                        argv[0], stmpdir, errno);
 	DIE;
    }

    /* extract embedded_files[0] (i.e. the custom Perl interpreter) 
     * into stmpdir (but under the same basename as argv[0]) */
    my_prog = par_findprog(argv[0], strdup(par_getenv("PATH")));
    rc = extract_embedded_file(embedded_files, par_basename(my_prog), stmpdir, &my_perl);
    if (rc == EXTRACT_FAIL) {
        fprintf(stderr, "%s: extraction of %s (custom Perl interpreter) failed (errno=%i)\n", 
                            argv[0], my_perl, errno);
        DIE;
    }

    if (rc == EXTRACT_OK)       /* i.e. file didn't already exist */
    {
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

    /* extract the rest of embedded_files into stmpdir */
    emb_file = embedded_files + 1;
    while (emb_file->name) {
        if (extract_embedded_file(emb_file, emb_file->name, stmpdir, &my_file) == EXTRACT_FAIL) {
            fprintf(stderr, "%s: extraction of %s failed (errno=%i)\n", 
                                argv[0], my_file, errno);
            DIE;
        }
        emb_file++;
    }

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
    rc = spawnvpe(P_WAIT, my_perl, (const char* const*)argv, (const char* const*)environ);

    par_cleanup(stmpdir);
    exit(rc);
#else
    execvp(my_perl, argv);
    DIE;
#endif
}

