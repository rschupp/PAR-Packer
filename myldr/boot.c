#undef readdir

#ifdef _MSC_VER
#include <io.h>
#else
#include <sys/types.h>
#include <unistd.h>
#include <stdio.h>
#include <stdarg.h>
#endif
#ifdef __MACH__
#include <sys/sysctl.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <stdlib.h>
#include <string.h> 
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
    int len = strlen(stmpdir) + 1 + strlen(ext_name);
    char *tmp_path;

    *ext_path = malloc(len + 1);
    sprintf(*ext_path, "%s/%s", stmpdir, ext_name);

    if (par_lstat(*ext_path, &statbuf) == 0 && statbuf.st_size == emb_file->size )
        return EXTRACT_ALREADY; /* file already exists and has the expected size */

    tmp_path = malloc(len + 1 + 20 + 1); /* 20 decimal digits should be enough to hold up to 2^64-1 */
    sprintf(tmp_path, "%s.%lu", *ext_path, (unsigned long)getpid());

    fd = open(tmp_path, O_CREAT | O_WRONLY | OPEN_O_BINARY, 0755);
    if ( fd == -1 ) 
        return EXTRACT_FAIL;

    chunk = emb_file->chunks;
    while (chunk->len) {
        if ( write(fd, chunk->buf, chunk->len) != chunk->len ) 
            return EXTRACT_FAIL;
        chunk++;
    }
    if (close(fd) == -1)
        return EXTRACT_FAIL;

    chmod(tmp_path, 0750);
    if (rename(tmp_path, *ext_path) == -1)
        unlink(tmp_path);
        /* NOTE: The error presumably is something like ETXTBSY (scenario:
         * another process was faster at extraction *ext_path than us and is
         * already using it in some way); anyway, let's assume *ext_path
         * is "good" and clean up our copy.
         */

    return EXTRACT_OK;
}

/* Simple magic number reader for MacOS */
#ifdef __MACH__
uint32_t read_magic(FILE *obj_file, int offset) {
  uint32_t magic;
  fseek(obj_file, offset, SEEK_SET);
  fread(&magic, sizeof(uint32_t), 1, obj_file);
  return magic;
}

/* double slashes in the tmpdir path confuse execve on macOS */
char *sanitise_tmp(char *s) {
  if (s) {
    const char *src = s;
    char *dst = s;
    while ((*dst = *src) != '\0') {
      do {
        src++;
      } while (*dst == '/' && *src == '/');
      dst++;
    }
  }  
  return s;
}
#endif

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

/* algorithm stolen from Win32::ShellQuote, in particular quote_literal() */
char* shell_quote(const char *src)
{
    /* some characters from src may be replaced with two chars,
     * add enclosing quotes and trailing \0 */
    char *dst = malloc(2 * strlen(src) + 3);

    const char *p = src;
    char *q = dst;
    char c;

    *q++ = '"';                         /* opening quote */

    while (c = *p)
    {
        if (c == '\\') 
        {
            int n = strspn(p, "\\");    /* span of backslashes starting at p */

            memcpy(q, p, n);            /* copy the span */
            q += n;

            if (p[n] == '\0' || p[n] == '"') /* span ends in quote or NUL */
            {
                memcpy(q, p, n);        /* copy the span once more */
                q += n;
            }

            p += n;                     /* advance over the span */
            continue;
        }

        if (c == '"')
            *q++ = '\\';                /* escape the following quote */
        *q++ = c;
        p++;
    }

    *q++ = '"';                         /* closing quote */
    *q++ = '\0';

    return dst;
}
#endif

void die(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    vfprintf(stderr, format, ap);
    va_end(ap);
    
    exit(255);
}

char pp_version_info[] = "@(#) Packed by PAR::Packer " PAR_PACKER_VERSION;

/* the contents of this string (in the executable myldr/boot)
 * will be patched by script/par.pl if option "--clean" is used with pp
 */
static char pass_par_clean[] = "__PASS_PAR_CLEAN__               \0";

int main ( int argc, char **argv, char **env )
{
    int rc;
    char *stmpdir;
    embedded_file_t *emb_file;
    char *my_file;
    char *my_perl;
    char *my_prog;
#ifdef WIN32
typedef BOOL (WINAPI *pALLOW)(DWORD);
    HINSTANCE hinstLib;
    pALLOW ProcAdd;
    char **argp;
#ifndef ASFW_ANY
#define ASFW_ANY -1
#endif
#endif

    par_init_env();

    /* check for patched content of pass_par_clean */
    {
        char *equals = strchr(pass_par_clean, '=');
        if (equals != NULL) {
            equals[2] = '\0';    /* trim value to one byte */
            par_setenv("PAR_CLEAN", equals + 1);
        }
    }

    stmpdir = par_mktmpdir( argv );
    if ( !stmpdir ) die("");        /* error message has already been printed */

    rc = my_mkdir(stmpdir, 0700);
    if ( rc == -1 && errno != EEXIST) {
	die("%s: creation of private cache subdirectory %s failed (errno= %i)\n", 
            argv[0], stmpdir, errno);
    }

    /* extract embedded_files[0] (i.e. the custom Perl interpreter) 
     * into stmpdir (but under the same basename as argv[0]) */
    my_prog = par_findprog(argv[0], par_getenv("PATH"));

#ifdef __MACH__
    {
        /* Detect if FAT binary */
        FILE *obj_file = fopen(my_prog, "rb");
        uint32_t magic = read_magic(obj_file, 0);
        fclose(obj_file);

        if (magic == FAT_CIGAM || magic == FAT_MAGIC) 
        {
            /* Create separate dir for extracted thin binary*/
            char *ftmpdir = malloc(strlen(stmpdir) + 5 + 1);
            sprintf(ftmpdir, "%s%s", stmpdir, "/thin");
            sanitise_tmp(ftmpdir);
            rc = my_mkdir(ftmpdir, 0700);
            if (rc == -1 && errno != EEXIST)
                die("%s: creation of cache subdirectory "
                    "for extracted macOS thin binary %s failed (errno= %i)\n", 
                    argv[0], ftmpdir, errno);
            
            /* Get architecture name */
            size_t size;
            sysctlbyname("hw.machine", NULL, &size, NULL, 0);
            char *arch = malloc(size);
            sysctlbyname("hw.machine", arch, &size, NULL, 0);

            /* Detect if CLT are installed, if not, die */
            int x = system("/usr/bin/xcode-select -p 1>/dev/null 2>/dev/null");
            if (x != 0) 
              die("%s: Command Line Tools are not installed - "
                  "run 'xcode-select --install' to install (errno=%i)\n", 
                  argv[0], errno);

            int exist;
            struct stat buffer;
            char *archthinbin = malloc(strlen(ftmpdir) + 1 + strlen(par_basename(my_prog)) + 1);
            sprintf(archthinbin, "%s/%s", ftmpdir, par_basename(my_prog));
            char* lipo_argv[] = { "lipo", "-extract_family", arch, "-output", archthinbin, my_prog, NULL };
            pid_t pid = fork();
            if (pid == -1) 
                die("%s: fork failed (errno=%i)\n",  argv[0], errno);
            if (pid == 0)
            {
                /* child */
                execve("/usr/bin/lipo", lipo_argv, env);
                exit(1);
            }

            /* parent */
            int wstatus;
            waitpid(pid, &wstatus, 0);
            if (!(WIFEXITED(wstatus) && WEXITSTATUS(wstatus) == 0))
                die("%s: extracting %s binary with lipo failed (wstatus=%i)\n",
                    argv[0], arch, wstatus);
            free(arch);

            /* exec correct thin binary */
            exist = stat(archthinbin, &buffer);
            if (exist == -1)
                die("%s: cannot find thin binary %s to run (errno=%i)\n", 
                    argv[0], archthinbin, errno);

            argv[0] = archthinbin;
            execve(archthinbin, argv, env);
            die("%s: cannot execute thin binary %s (errno=%i)\n", 
                argv[0], archthinbin, errno);
        }
    }
#endif    
    
    rc = extract_embedded_file(embedded_files, par_basename(my_prog), stmpdir, &my_perl);
    if (rc == EXTRACT_FAIL) {
        die("%s: extraction of %s (custom Perl interpreter) failed (errno=%i)\n", 
            argv[0], my_perl, errno);
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
            die("%s: extraction of %s failed (errno=%i)\n", 
                argv[0], my_file, errno);
        }
        emb_file++;
    }

    /* finally spawn the custom Perl interpreter */
    argv[0] = my_perl;
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

    /* quote argv strings if necessary, cf. Win32::ShellQuote */
    for (argp = argv; *argp; argp++)
    {
        int len = strlen(*argp);
        if ( len == 0 
             || (*argp)[len-1] == '\\'
             || strpbrk(*argp, " \t\n\r\v\"") )
        {
            *argp = shell_quote(*argp);
        }
    }

    rc = spawnvp(P_WAIT, my_perl, (char* const*)argv);

    par_cleanup(stmpdir);
    exit(rc);
#else
    execvp(my_perl, argv);
    die("%s: exec of %s (custom Perl interpreter) failed (errno=%i)\n", 
        argv[0], my_perl, errno);
#endif
}

