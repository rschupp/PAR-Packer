#undef readdir

#ifdef WIN32
#include <windows.h>
#include <wchar.h>
#include <stdio.h>
#include <shellapi.h>
#include <stringapiset.h>
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
    char *tmp_path;

    *ext_path = malloc(strlen(stmpdir) + 1 + strlen(ext_name) + 1);
    sprintf(*ext_path, "%s/%s", stmpdir, ext_name);

    if (par_lstat(*ext_path, &statbuf) == 0 && statbuf.st_size == emb_file->size )
        return EXTRACT_ALREADY; /* file already exists and has the expected size */

    tmp_path = malloc(strlen(*ext_path) + 1 + 20 + 1); 
                                /* 20 decimal digits should be enough to hold up to 2^64-1 */
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

    CHECK(lseek(fd, 0, SEEK_SET) != -1, "lseek failed");
    CHECK(read(fd, buf, 64) == 64, "short read");
    ASSERT(unpack_S(buf) == 0x5a4d, "MZ magic bytes");    // "MZ"
    off = unpack_L(buf+60);

    CHECK(lseek(fd, off, SEEK_SET) != -1, "lseek failed");
    CHECK(read(fd, buf, 4 + 20 + 2) == 4 + 20 + 2, "short read");
    ASSERT(unpack_L(buf) == 0x4550, "PE header");    // "PE\0\0"
    size = unpack_S(buf+20);
    magic = unpack_S(buf+24);
    ASSERT(( size == 224 && magic == 0x10b ) 
           || ( size == 240 && magic == 0x20b ), "IMAGE_NT_OPTIONAL_HDR_MAGIC");

    CHECK(lseek(fd, off + 4 + 20 + 68, SEEK_SET) != -1, "lseek failed");
}

/* algorithm stolen from Win32::ShellQuote, in particular quote_literal() */
wchar_t* shell_quote_wide(const wchar_t *src)
{
    /* some characters from src may be replaced with two chars,
     * add enclosing quotes and trailing \0 */
    wchar_t *dst = malloc((2 * wcslen(src) + 3) * sizeof(wchar_t));

    const wchar_t *p = src;
    wchar_t *q = dst;
    wchar_t c;

    *q++ = L'"';                         /* opening quote */

    while ((c = *p))
    {
        if (c == L'\\')
        {
            int n = wcsspn(p, L"\\");    /* span of backslashes starting at p */

            wmemcpy(q, p, n);
            q += n;

            if (p[n] == L'\0' || p[n] == L'"') /* span ends in quote or NUL */
            {
                wmemcpy(q, p, n);
                q += n;
            }

            p += n;                     /* advance over the span */
            continue;
        }

        if (c == L'"')
            *q++ = L'\\';                /* escape the following quote */
        *q++ = c;
        p++;
    }

    *q++ = L'"';                         /* closing quote */
    *q++ = L'\0';

    return dst;
}

void spawn_perl(const char *argv0, const char *my_perl, const char *stmpdir)
{
    typedef BOOL (WINAPI *pALLOW)(DWORD);
    HINSTANCE hinstLib;
    pALLOW ProcAdd;
#ifndef ASFW_ANY
#define ASFW_ANY -1
#endif
    LPWSTR *w_argv;
    LPWSTR w_my_perl;
    int w_argc, i, len, rc;

    hinstLib = LoadLibrary("user32");
    if (hinstLib != NULL) {
        ProcAdd = (pALLOW) GetProcAddress(hinstLib, "AllowSetForegroundWindow");
        if (ProcAdd != NULL)
        {
            (ProcAdd)(ASFW_ANY);
        }
    }

    w_argv = CommandLineToArgvW(GetCommandLineW(), &w_argc);
    if (w_argv == NULL)
        par_die("%s: GetCommandLineW or CommandLineToArgvW failed: $^E=%u", 
                argv0, GetLastError());

    /* convert my_perl from local codepage to UTF-16 */
    len = MultiByteToWideChar(CP_THREAD_ACP, 0, my_perl, -1, NULL, 0);
    if (len == 0)
        par_die("%s: failed to convert string to UTF-16: $^E=%u", 
                argv0, GetLastError());
    w_my_perl = malloc(len * sizeof(wchar_t));        /* len includes trailing NUL */
    len = MultiByteToWideChar(CP_THREAD_ACP, 0, my_perl, -1, w_my_perl, len);
    w_argv[0] = w_my_perl;

    for (i = 0; i < w_argc; i++)
    {
        len = wcslen(w_argv[i]);
        if (len == 0 
            || w_argv[i][len-1] == L'\\'
            || wcspbrk(w_argv[i], L" \t\n\r\v\""))
        {
            w_argv[i] = shell_quote_wide(w_argv[i]);
        }
    }    

    par_setenv("PAR_SPAWNED", "1");

    rc = _wspawnvp(P_WAIT, w_my_perl, (const wchar_t* const*)w_argv);
    
    free(w_my_perl);
    LocalFree(w_argv);

    par_cleanup(stmpdir);
    exit(rc);
}
#endif

char pp_version_info[] = "@(#) Packed by PAR::Packer " stringify(PAR_PACKER_VERSION);

/* the contents of this string (in the executable myldr/boot)
 * will be patched by script/par.pl if option "--clean" is used with pp
 */

int main ( int argc, char **argv, char **env )
{
    int rc;
    char *stmpdir;
    embedded_file_t *emb_file;
    char *my_file;
    char *my_perl;
    char *my_prog;

    par_init_env();

    stmpdir = par_mktmpdir( argv );
    if ( !stmpdir ) par_die("");        /* error message has already been printed */

    rc = my_mkdir(stmpdir, 0700);
    if ( rc == -1 && errno != EEXIST) {
	par_die("%s: creation of private cache subdirectory %s failed (errno= %i)\n", 
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
                par_die("%s: creation of cache subdirectory "
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
                par_die("%s: Command Line Tools are not installed - "
                        "run 'xcode-select --install' to install (errno=%i)\n", 
                        argv[0], errno);

            int exist;
            struct stat buffer;
            char *archthinbin = malloc(strlen(ftmpdir) + 1 + strlen(par_basename(my_prog)) + 1);
            sprintf(archthinbin, "%s/%s", ftmpdir, par_basename(my_prog));
            char* lipo_argv[] = { "lipo", "-extract_family", arch, "-output", archthinbin, my_prog, NULL };
            pid_t pid = fork();
            if (pid == -1) 
                par_die("%s: fork failed (errno=%i)\n",  argv[0], errno);
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
                par_die("%s: extracting %s binary with lipo failed (wstatus=%i)\n",
                        argv[0], arch, wstatus);
            free(arch);

            /* exec correct thin binary */
            exist = stat(archthinbin, &buffer);
            if (exist == -1)
                par_die("%s: cannot find thin binary %s to run (errno=%i)\n", 
                        argv[0], archthinbin, errno);

            argv[0] = archthinbin;
            execve(archthinbin, argv, env);
            par_die("%s: cannot execute thin binary %s (errno=%i)\n", 
                    argv[0], archthinbin, errno);
        }
    }
#endif    
    
    rc = extract_embedded_file(embedded_files, par_basename(my_prog), stmpdir, &my_perl);
    if (rc == EXTRACT_FAIL) {
        par_die("%s: extraction of %s (custom Perl interpreter) failed (errno=%i)\n", 
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
            CHECK(read(fd, &subsystem, 2) == 2, "short read");
            CHECK(close(fd) != -1, "close failed");

            fd = open(my_perl, O_RDWR | OPEN_O_BINARY, 0755);
            ASSERT(fd != -1, "open my_perl");
            seek_to_subsystem(fd);
            CHECK(write(fd, &subsystem, 2) == 2, "short write");
            CHECK(close(fd) != -1, "close failed");
        }
#endif
    }

    /* extract the rest of embedded_files into stmpdir */
    emb_file = embedded_files + 1;
    while (emb_file->name) {
        if (extract_embedded_file(emb_file, emb_file->name, stmpdir, &my_file) == EXTRACT_FAIL) {
            par_die("%s: extraction of %s failed (errno=%i)\n", 
                    argv[0], my_file, errno);
        }
        emb_file++;
    }

    /* finally spawn the custom Perl interpreter */
#ifdef WIN32
    spawn_perl(argv[0], my_perl, stmpdir);       /* no return */
#else
    argv[0] = my_perl;
    execvp(my_perl, argv);
    par_die("%s: exec of %s (custom Perl interpreter) failed (errno=%i)\n", 
            argv[0], my_perl, errno);
#endif
}

