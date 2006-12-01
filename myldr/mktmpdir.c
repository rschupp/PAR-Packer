#include "mktmpdir.h"

#define PAR_TEMP "PAR_TEMP"

#ifdef O_BINARY
#  define OPEN_O_BINARY O_BINARY
#else
#  define OPEN_O_BINARY 0
#endif

void par_setup_libpath( const char * stmpdir )
{
   const char *key = NULL , *val = NULL;
   int i;
   const char *ld_path_keys[6] = {
      "LD_LIBRARY_PATH", "LIBPATH", "LIBRARY_PATH",
      "PATH", "DYLD_LIBRARY_PATH", ""
   };
   char *ld_path_env = NULL;
    for ( i = 0 ; strlen(key = ld_path_keys[i]) > 0 ; i++ ) {
        if ( ((val = (char *)par_getenv(key)) == NULL) || (strlen(val) == 0) ) {
            par_setenv(key, stmpdir);
        }
        else if(!strstr(val, stmpdir)) {
            ld_path_env = (char *)malloc(
                strlen(stmpdir) +
                strlen(path_sep) +
                strlen(val) + 2
            );
            sprintf(
                ld_path_env,
				"%s%s%s",
                stmpdir, path_sep, val
            );
            par_setenv(key, ld_path_env);
        }
    }
}

char *par_mktmpdir ( char **argv ) {
    int i;
    char *c;
    const char *tmpdir = NULL;
    const char *key = NULL , *val = NULL;

    const char *temp_dirs[4] = { "C:\\TEMP", "/tmp", ".", "" };
    const char *temp_keys[6] = { "PAR_TMPDIR", "TMPDIR", "TEMPDIR", "TEMP", "TMP", "" };
    const char *user_keys[3] = { "USER", "USERNAME", "" };

    const char *subdirbuf_prefix = "par-";
    const char *subdirbuf_suffix = "";

    char *progname = NULL, *username = NULL;
    char *stmpdir = NULL;
    int f, j, k, stmp_len = 0;
    char sha1[41];
    SHA_INFO sha_info;
    unsigned char buf[32768];
    unsigned char sha_data[20];

#ifndef PL_statbuf
struct stat PL_statbuf;
#endif

    if ( (val = (char *)par_getenv(PAR_TEMP)) && strlen(val) ) {
        par_setup_libpath(val);
        return strdup(val);
    }

#ifdef WIN32
    {
        DWORD buflen = MAXPATHLEN;
        username = (char *)malloc(MAXPATHLEN);
        GetUserName((LPTSTR)username, &buflen);
    }
#endif

    /* Determine username */
    username = get_username_from_getpwuid();
    if ( username == NULL ) { /* fall back to env vars */
        for (
                i = 0 ;
                username == NULL && strlen(key = user_keys[i]) > 0 ;
                i++
            )
        {
            if ( (val = (char *)par_getenv(key)) ) username = strdup(val);
        }
    }

    if ( username == NULL ) {
        username = "SYSTEM";
    }
    else {
        /* replace all non-alphanumeric letters with '_' */
        for ( c = username ; *c != '\0' ; c++ ) {
            if ( !isalnum(*c) ) {
                *c = '_';
            }
        }
    }

    for ( i = 0 ; tmpdir == NULL && strlen(key = temp_keys[i]) > 0 ; i++ ) {
        if ( (val = (char *)par_getenv(key)) &&
             par_lstat(val, &PL_statbuf) == 0 &&
             ( S_ISDIR(PL_statbuf.st_mode) ||
               S_ISLNK(PL_statbuf.st_mode) ) &&
             access(val, W_OK) == 0 ) {
            tmpdir = strdup(val);
        }
    }

    for ( i = 0 ; tmpdir == NULL && strlen(val = temp_dirs[i]) > 0 ; i++ ) {
        if ( par_lstat(val, &PL_statbuf) == 0 &&
             ( S_ISDIR(PL_statbuf.st_mode) ||
               S_ISLNK(PL_statbuf.st_mode) ) &&
             access(val, W_OK) == 0 ) {
            tmpdir = strdup(val);
        }
    }

    /* "$TEMP/par-$USER" */
    stmp_len = 
        strlen(tmpdir) +
        strlen(subdirbuf_prefix) +
        strlen(username) +
        strlen(subdirbuf_suffix) + 1024;

    /* stmpdir is what we are going to return 
       stmpdir2 is the top $TEMP/par-$USER, needed to build stmpdir.  We
       need 2 buffers because snprintf() can't write to a buffer it's
       reading from. */
    stmpdir = malloc( stmp_len );
    sprintf(stmpdir, "%s%s%s%s", tmpdir, dir_sep, subdirbuf_prefix, username);
    my_mkdir(stmpdir, 0755);

    /* Doesn't really work - XXX */
    val = (char *)par_getenv( "PATH" );
    progname = par_findprog(argv[0], strdup(val));
    if (progname == NULL) progname = argv[0];

    if ( !par_env_clean() && (f = open( progname, O_RDONLY | OPEN_O_BINARY ))) {
        lseek(f, -18, 2);
        read(f, buf, 6);
        if(buf[0] == 0 && buf[1] == 'C' && buf[2] == 'A' && buf[3] == 'C' && buf[4] == 'H' && buf[5] == 'E') {
            /* pre-computed cache_name in this file */
            /* "$TEMP/par-$USER/cache-$cache_name" */
            lseek(f, -58, 2);
            read(f, buf, 41);
            sprintf(
                stmpdir,
                "%s%scache-%s%s",
                stmpdir, dir_sep, buf, subdirbuf_suffix
            );
        }
        else {
            /* "$TEMP/par-$USER/cache-$SHA1" */
            sha_init( &sha_info );
            while( ( j = read( f, buf, sizeof( buf ) ) ) > 0 )
            {
                sha_update( &sha_info, buf, j );
            }
            close( f );
            sha_final( sha_data, &sha_info );
            for( k = 0; k < 20; k++ )
            {
                sprintf( sha1+k*2, "%02x", sha_data[k] );
            }
            sha1[40] = '\0';
            sprintf(
                stmpdir,
                "%s%scache-%s%s",
                stmpdir, dir_sep, sha1, subdirbuf_suffix
            );
        }
    }
    else {
        /* "$TEMP/par-$USER/temp-$PID" */

        par_setenv("PAR_CLEAN", "1");
        sprintf(
            stmpdir,
            "%s%stemp-%u%s",
            stmpdir, dir_sep, getpid(), subdirbuf_suffix
        );
    }

    /* set dynamic loading path */
    par_setenv(PAR_TEMP, stmpdir);

    par_setup_libpath( stmpdir );

    return(stmpdir);
}


#ifdef WIN32
void par_rmtmpdir ( char *stmpdir, int recurse ) {
    struct _finddata_t cur_file;
    int subsub_len;
    char *subsubdir;
    char *slashdot;
    long hFile;
	int tries = 0;
    HMODULE dll;

    if ((stmpdir == NULL) || !strlen(stmpdir)) return;

    subsub_len = strlen(stmpdir) + 258;
    subsubdir = malloc( subsub_len );

    sprintf(subsubdir, "%s\\*.*", stmpdir);
    
    hFile = _findfirst( subsubdir, &cur_file );
    if ( hFile == -1 ) return;

    if (!strstr(cur_file.name, "\\")) {
        sprintf(subsubdir, "%s\\%s", stmpdir, cur_file.name);
    }
    else {
        sprintf(subsubdir, "%s", cur_file.name);
    }

    if (!(slashdot = strstr(subsubdir, "\\.")) || (strcmp(slashdot,"\\.") && strcmp(slashdot,"\\.."))) {
        if ((cur_file.attrib & _A_SUBDIR) && recurse) {
            par_rmtmpdir( subsubdir, 1 );
        }
        /* if (!(cur_file.attrib & _A_SUBDIR)) fprintf(stderr, "unlinking %s\n", subsubdir); */
        else {
            dll = GetModuleHandle(cur_file.name);
            tries = 0;
            while ( _unlink(subsubdir) && ( tries++ < 10 ) ) {
                if ( dll ) FreeLibrary(dll);
            };
        }
    }
    while ( _findnext( hFile, &cur_file ) == 0 ) {
        if (!strstr(cur_file.name, "\\")) {
            sprintf(subsubdir, "%s\\%s", stmpdir, cur_file.name);
        }
        else {
            sprintf(subsubdir, "%s", cur_file.name);
        }

        if (!(slashdot = strstr(subsubdir, "\\.")) || (strcmp(slashdot,"\\.") && strcmp(slashdot,"\\.."))) {
            if ((cur_file.attrib & _A_SUBDIR) && recurse) {
                par_rmtmpdir( subsubdir, 1 );
            }
            /* if (!(cur_file.attrib & _A_SUBDIR)) fprintf(stderr, "unlinking %s\n", subsubdir); */
            else {
                dll = GetModuleHandle(cur_file.name);
                tries = 0;
                while ( _unlink(subsubdir) && ( tries++ < 10 ) ) {
                    if ( dll ) FreeLibrary(dll);
                };
            }
        }
    }

    _findclose(hFile);
    _rmdir(stmpdir);
}

#else
void par_rmtmpdir ( char *stmpdir, int recurse ) {
    DIR *partmp_dirp;
    Direntry_t *dp;
    char *subsubdir = NULL;
    int  subsub_len;
    struct stat stbuf;

    /* remove temporary PAR directory */
    partmp_dirp = opendir(stmpdir);

    if ( partmp_dirp == NULL ) return;

    /* fprintf(stderr, "%s: removing private temporary subdirectory %s.\n", argv[0], stmpdir); */
    while ( ( dp = readdir(partmp_dirp) ) != NULL ) {
        if ( strcmp (dp->d_name, ".") != 0 && strcmp (dp->d_name, "..") != 0 )
        {
            subsub_len = strlen(stmpdir) + strlen(dp->d_name) + 2;
            subsubdir = malloc( subsub_len);
            sprintf(subsubdir, "%s/%s", stmpdir, dp->d_name);
            if (stat(subsubdir, &stbuf) != -1 && S_ISDIR(stbuf.st_mode) && recurse) {
                par_rmtmpdir(subsubdir, 1);
            }
            else {
                unlink(subsubdir);
            }
            free(subsubdir);
            subsubdir = NULL;
        }
    }

    closedir(partmp_dirp);
    if (stmpdir) rmdir(stmpdir);
}
#endif

void par_cleanup (char *stmpdir) {
    char *dirname = par_dirname(stmpdir);
    char *basename = par_basename(dirname);
    if ( par_env_clean() && stmpdir != NULL && strlen(stmpdir)) {
        if ( strstr(basename, "par-") == basename ) {
            par_rmtmpdir(stmpdir, 1);
            par_rmtmpdir(dirname, 0);
        }
    }
}
