#include "mktmpdir.h"
#include "sha1.h"

#ifdef O_BINARY
#  define OPEN_O_BINARY O_BINARY
#else
#  define OPEN_O_BINARY 0
#endif

#ifndef P_tmpdir
#define P_tmpdir "/tmp"
#endif

/* NOTE: This code is #include'd both from a plain C program (boot.c)
 * and our custom Perl interpreter (main.c). In the latter case,
 * lstat() or stat() may be #define'd as calls into PerlIO and
 * expect pointer to a Stat_t as second parameter, rather than a pointer
 * to a struct stat. Try to distinguish these cases by checking
 * whether Stat_t is defined. */
#ifndef Stat_t
#define Stat_t struct stat
#endif

static char PAR_MAGIC[] = "\nPAR.pm\n";
#define magic_size 8

/* "\0CACHE" or "\0CLEAN" */
#define cache_marker_size 6

/* size of a pack("N") number */
#define FILE_offset_size 4

#define cache_name_size 40

#define CHECK(code, msg) if (!(code)) { par_die(msg); }


static int isWritableDir(const char* val)
{
    Stat_t statbuf;

    return par_lstat(val, &statbuf) == 0 && 
           ( S_ISDIR(statbuf.st_mode) || S_ISLNK(statbuf.st_mode) ) &&
           access(val, W_OK) == 0;
}

#ifndef WIN32
/* check that:
 * - val is a directory (and not a symlink)
 * - val is owned by the user
 * - val has mode 0700
 */
static int isSafeDir(const char* val)
{
    Stat_t statbuf;

    return par_lstat(val, &statbuf) == 0 && 
           S_ISDIR(statbuf.st_mode) &&
           statbuf.st_uid == getuid() &&
           (statbuf.st_mode & 0777) == 0700;
}
#endif

void par_setup_libpath( const char * stmpdir )
{
    const char *ldlibpthname = stringify(LDLIBPTHNAME);
    const char *val;

    if ( (val = par_getenv(ldlibpthname)) == NULL || strlen(val) == 0 ) {
        par_setenv(ldlibpthname, stmpdir);
    }
    else {
        /* prepend stmpdir to (value of) environment variable */
       char *new_val = malloc( 
            strlen(stmpdir) + strlen(path_sep) + strlen(val) + 1);
        sprintf(
            new_val, "%s%s%s",
            stmpdir, path_sep, val);
        par_setenv(ldlibpthname, new_val);
    }
}

static void *par_memrmem(void* haystack, size_t haystacklen, void* needle, size_t needlelen)
{
    char *hs = haystack;
    char *p;
    if (haystacklen < needlelen)
        return NULL;
    for (p = hs + haystacklen - needlelen; p >= hs; p--)
        if (memcmp(p, needle, needlelen) == 0)
            return p;
    return NULL;
}

static off_t find_par_magic(int fd)
{
#define CHUNK_SIZE (64 * 1024)
    char buf[CHUNK_SIZE + magic_size];
    off_t pos;
    int len;
    char *p;
    off_t file_size = lseek(fd, 0, 2);

    for (pos = (file_size-1) - (file_size-1) % CHUNK_SIZE; 
         pos >= 0; 
         pos -= CHUNK_SIZE) {
        CHECK(lseek(fd, pos, 0) != -1, "lseek failed");
        len = read(fd, buf, CHUNK_SIZE + magic_size);
        CHECK(len != -1, "read failed");
        p = par_memrmem(buf, len, PAR_MAGIC, magic_size);
        if (p)
            return pos + (p - buf);
    }
    return -1;
#undef CHUNK_SIZE
}

char *par_mktmpdir ( char **argv ) {
    int i;
    const char *tmpdir = NULL;
    const char *key = NULL , *val = NULL;

    /* NOTE: all arrays below are NULL terminated */
    const char *temp_dirs[] = { 
        P_tmpdir, 
#ifdef WIN32
        "C:\\TEMP", 
#endif
        ".", NULL };
    const char *temp_keys[] = { "PAR_TMPDIR", "TMPDIR", "TEMPDIR", 
                                 "TEMP", "TMP", NULL };
    const char *user_keys[] = { "USER", "USERNAME", NULL };

    const char *subdirbuf_prefix = "par-";
    const char *subdirbuf_suffix = "";

    char *progname = NULL, *username = NULL;
    char *stmpdir = NULL, *top_tmpdir = NULL;
    int f, j, k, stmp_len = 0;
    char sha1[cache_name_size + 1];

    if ( (val = par_getenv("PAR_TEMP")) && strlen(val) ) {
        par_setup_libpath(val);
        return strdup(val);
    }

#ifdef WIN32
    {
        DWORD buflen = MAXPATHLEN;
        username = malloc(MAXPATHLEN);
        GetUserName((LPTSTR)username, &buflen);
        // FIXME this is uncondifionally overwritten below - WTF?
    }
#endif

    /* Determine username */
    username = get_username_from_getpwuid();
    if ( !username ) { /* fall back to env vars */
        for ( i = 0 ; username == NULL && (key = user_keys[i]); i++) {
            if ( (val = par_getenv(key)) && strlen(val) ) 
                username = strdup(val);
        }
    }
    if ( username == NULL )
        username = "SYSTEM";
   
    /* sanitize username: encode all bytes as 2 hex digits */
    {
        char *hexname = malloc(2 * strlen(username) + 1);
        char *u, *h;
        for ( u = username, h = hexname ; *u != '\0' ; u++, h += 2)
            sprintf(h, "%02x", *(unsigned char*)u);
        username = hexname;
    }

    /* Try temp environment variables */
    for ( i = 0 ; tmpdir == NULL && (key = temp_keys[i]); i++ ) {
        if ( (val = par_getenv(key)) && strlen(val) && isWritableDir(val) ) {
            tmpdir = strdup(val);
            break;
        }
    }

#ifdef WIN32
    /* Try the windows temp directory */
    if ( tmpdir == NULL && (val = par_getenv("WinDir")) && strlen(val) ) {
        char* p = malloc(strlen(val) + 5 + 1);
        sprintf(p, "%s\\temp", val);
        if (isWritableDir(p)) {
            tmpdir = p;
        } else {
            free(p);
        }
    }
#endif

    /* Try default locations */
    for ( i = 0 ; tmpdir == NULL && (val = temp_dirs[i]) && strlen(val) ; i++ ) {
        if ( isWritableDir(val) ) {
            tmpdir = strdup(val);
        }
    }

    /* "$TEMP/par-$USER" */
    stmp_len = 
        strlen(tmpdir) +
        strlen(subdirbuf_prefix) +
        strlen(username) +
        strlen(subdirbuf_suffix) + 1024;

    /* stmpdir is what we are going to return; 
       top_tmpdir is the top $TEMP/par-$USER, needed to build stmpdir.  
       NOTE: We need 2 buffers because snprintf() can't write to a buffer
       it is also reading from. */
    top_tmpdir = malloc( stmp_len );
    sprintf(top_tmpdir, "%s%s%s%s", tmpdir, dir_sep, subdirbuf_prefix, username);
#ifdef WIN32
    _mkdir(top_tmpdir);         /* FIXME bail if error (other than EEXIST) */
#else
    {
        if (mkdir(top_tmpdir, 0700) == -1 && errno != EEXIST) {
            fprintf(stderr, "%s: creation of private subdirectory %s failed (errno=%i)\n", 
                    argv[0], top_tmpdir, errno);
            return NULL;
        }

        if (!isSafeDir(top_tmpdir)) {
            fprintf(stderr, "%s: private subdirectory %s is unsafe (please remove it and retry your operation)\n",
                    argv[0], top_tmpdir);
            return NULL;
        }
    }
#endif

    stmpdir = malloc( stmp_len );

    /* Doesn't really work - XXX */
    val = par_getenv( "PATH" );
    if (val != NULL)
        progname = par_findprog(argv[0], val);
    if (progname == NULL)
        progname = argv[0];

    /* If invoked as "/usr/bin/parl foo.par myscript.pl" then progname should
     * be ".../parl", and we don't want to base our checksum on that, but
     * rather on "foo.par".
     */
    {
#ifdef WIN32
#define STREQ(a,b) (strcasecmp(a,b) == 0)
#else
#define STREQ(a,b) (strcmp(a,b) == 0)
#endif
        const char *parl_exe = stringify(PARL_EXE);
	int prog_len = strlen(progname);
	int parl_len = strlen(parl_exe);

	if (prog_len >= parl_len
	    && STREQ(progname + prog_len - parl_len, parl_exe)
	    && (prog_len == parl_len || progname[prog_len - parl_len - 1] == dir_sep[0])
	    && argv[1]
	    && strlen(argv[1]) >= 4
	    && STREQ(argv[1] + strlen(argv[1]) - 4, ".par"))
		progname = argv[1];
#undef STREQ
    }

    int use_cache = 0;
    if ( !par_env_clean() && (f = open( progname, O_RDONLY | OPEN_O_BINARY ))) {
        off_t pos = find_par_magic(f);
        char buf[cache_marker_size];

        if (pos >= 0) {                 
            /* back up over pack(N) number and "\0CACHE" (or "\0CLEAN") */
            pos -= FILE_offset_size + cache_marker_size;                  
            lseek(f, pos, 0); 
            CHECK(read(f, buf, cache_marker_size) == cache_marker_size, "short read");
            if (memcmp(buf, "\0CACHE", cache_marker_size) == 0) {
                use_cache = 1;
                /* back up over pre-computed cache_name */
                pos -= cache_name_size;
                lseek(f, pos, 0);
                CHECK(read(f, sha1, cache_name_size) == cache_name_size, "short read");
                sha1[cache_name_size] = '\0';
            }
            else if (memcmp(buf, "\0CLEAN", cache_marker_size) == 0) {
                use_cache = 0;
            }
        }
    }
    if (use_cache) {
        /* "$TEMP/par-$USER/cache-$SHA1" */
        sprintf(
            stmpdir,
            "%s%scache-%s%s",
            top_tmpdir, dir_sep, sha1, subdirbuf_suffix
        );
    }
    else {
        /* "$TEMP/par-$USER/temp-$PID" */
        par_setenv("PAR_CLEAN", "1");
        sprintf(
            stmpdir,
            "%s%stemp-%u%s",
            top_tmpdir, dir_sep, getpid(), subdirbuf_suffix
        );

        /* Ensure we pick an unused directory each time.  If the directory
           already exists when we try to create it, bump a counter and try
           "$TEMP/par-$USER/temp-$PID-$i". This will guard against cases where
           a prior invocation crashed leaving garbage in a temp directory that
           might interfere. */
        int i = 0;
        while (my_mkdir(stmpdir, 0700) == -1 && errno == EEXIST) {
            sprintf(
                stmpdir,
                "%s%stemp-%u-%u%s",
                top_tmpdir, dir_sep, getpid(), ++i, subdirbuf_suffix
                );
        }
    }

    free(top_tmpdir);

    /* set dynamic loading path */
    par_setenv("PAR_TEMP", stmpdir);

    par_setup_libpath( stmpdir );

    return stmpdir;
}


#ifdef WIN32
static void par_rmtmpdir ( char *stmpdir ) {
    struct _finddata_t cur_file;
    int subsub_len;
    char *subsubdir;
    char *slashdot;
    intptr_t hFile;
    int tries = 0;
    HMODULE dll;

    if ((stmpdir == NULL) || !strlen(stmpdir)) return;

    subsub_len = strlen(stmpdir) + 258;
    subsubdir = malloc( subsub_len );

    sprintf(subsubdir, "%s\\*.*", stmpdir);
    
    hFile = _findfirst( subsubdir, &cur_file );
    if ( hFile == -1 ) return;

    do {
        if (!strstr(cur_file.name, "\\")) {
            sprintf(subsubdir, "%s\\%s", stmpdir, cur_file.name);
        }
        else {
            sprintf(subsubdir, "%s", cur_file.name);
        }

        if (!(slashdot = strstr(subsubdir, "\\.")) || (strcmp(slashdot,"\\.") && strcmp(slashdot,"\\.."))) {
            if ((cur_file.attrib & _A_SUBDIR)) {
                par_rmtmpdir( subsubdir );
            }
            else {
                dll = GetModuleHandle(cur_file.name);
                tries = 0;
                while ( _unlink(subsubdir) && ( tries++ < 10 ) ) {
                    if ( dll ) FreeLibrary(dll);
                };
            }
        }
    } while ( _findnext( hFile, &cur_file ) == 0 );

    _findclose(hFile);
    _rmdir(stmpdir);
}

#else
static void par_rmtmpdir ( char *stmpdir ) {
    DIR *partmp_dirp;
    Direntry_t *dp;
    char *subsubdir = NULL;
    int  subsub_len;
    Stat_t stbuf;

    /* remove temporary PAR directory */
    if (!stmpdir || !*stmpdir) return;

    partmp_dirp = opendir(stmpdir);

    if ( partmp_dirp == NULL ) return;

    while ( ( dp = readdir(partmp_dirp) ) != NULL ) {
        if ( strcmp (dp->d_name, ".") != 0 && strcmp (dp->d_name, "..") != 0 )
        {
            subsub_len = strlen(stmpdir) + 1 + strlen(dp->d_name) + 1;
            subsubdir = malloc( subsub_len);
            sprintf(subsubdir, "%s/%s", stmpdir, dp->d_name);
            if (stat(subsubdir, &stbuf) != -1 && S_ISDIR(stbuf.st_mode)) {
                par_rmtmpdir(subsubdir);
            }
            else {
                unlink(subsubdir);
            }
            free(subsubdir);
            subsubdir = NULL;
        }
    }

    closedir(partmp_dirp);
    rmdir(stmpdir);
}
#endif

void par_cleanup (char *stmpdir) {
    char *dirname, *basename;
    if ( par_env_clean() && stmpdir != NULL && strlen(stmpdir)) {
        dirname = par_dirname(stmpdir);
        basename = par_basename(dirname);
        if ( strstr(basename, "par-") == basename ) {
            par_rmtmpdir(stmpdir);
            /* Don't try to remove dirname because this will introduce a race
               with other applications that are trying to start. */
        }
    }
}
