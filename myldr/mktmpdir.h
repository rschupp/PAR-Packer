#ifdef _MSC_VER
#  if _MSC_VER < 1900
#    define snprintf _snprintf
#  endif
#  if _MSC_VER < 1500
#    define vsnprintf _vsnprintf
#  endif
#  define strncasecmp _strnicmp
#  define strcasecmp _stricmp
#endif

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#ifdef WIN32
#  include <direct.h>
#  define Direntry_t struct direct
#  include <windows.h>
#else
#  include <dirent.h>
#  define Direntry_t struct dirent
#  include <unistd.h>
#endif

#ifndef W_OK
#define W_OK 0x02
#endif

#ifndef X_OK
#define X_OK 0x04
#endif

#ifndef S_ISDIR
#   define S_ISDIR(m) ((m & S_IFMT) == S_IFDIR)
#endif

#ifndef S_ISLNK
#   ifdef _S_ISLNK
#       define S_ISLNK(m) _S_ISLNK(m)
#   else
#       ifdef _S_IFLNK
#           define S_ISLNK(m) ((m & S_IFMT) == _S_IFLNK)
#       else
#           ifdef S_IFLNK
#               define S_ISLNK(m) ((m & S_IFMT) == S_IFLNK)
#           else
#               define S_ISLNK(m) (0)
#           endif
#       endif
#   endif
#endif

#ifndef S_ISREG
#define S_ISREG(x) 1
#endif

#ifndef MAXPATHLEN
#define MAXPATHLEN 32767
#endif

#ifdef HAS_LSTAT
#define par_lstat lstat
#else
#define par_lstat stat
#endif

#if defined(WIN32) || defined(OS2)
static const char *dir_sep = "\\";
static const char *path_sep = ";";
#else
static const char *dir_sep = "/";
static const char *path_sep = ":";
#endif


#ifdef WIN32
#  include <process.h>
#  define my_mkdir(file, mode) _mkdir(file)
#else
#  define my_mkdir(file, mode) mkdir(file,mode)
#endif

#include "utils.c"
#include "usernamefrompwuid.c"

