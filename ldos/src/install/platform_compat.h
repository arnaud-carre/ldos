#ifndef PLATFORM_COMPAT_H
#define PLATFORM_COMPAT_H

#include <string.h>
#include <stdlib.h>

// Cross-platform compatibility macros and functions

#ifdef _WIN32
    // Windows already has these functions
    #include <direct.h>
    #define PATH_MAX _MAX_PATH
#else
    // POSIX/macOS/Linux implementations
    #include <strings.h>
    #include <libgen.h>
    #include <limits.h>

    // Safe string copy (replacement for strcpy_s)
    inline int strcpy_s(char* dest, size_t destsz, const char* src) {
        if (!dest || !src || destsz == 0) return -1;
        strncpy(dest, src, destsz - 1);
        dest[destsz - 1] = '\0';
        return 0;
    }

    // Safe file open (replacement for fopen_s)
    inline int fopen_s(FILE** pFile, const char* filename, const char* mode) {
        if (!pFile) return -1;
        *pFile = fopen(filename, mode);
        return (*pFile == NULL) ? -1 : 0;
    }

    // Case-insensitive string compare (replacement for _stricmp)
    #define _stricmp strcasecmp

    // String duplicate (replacement for _strdup)
    #define _strdup strdup

    // Path constants
    #ifndef _MAX_PATH
    #define _MAX_PATH PATH_MAX
    #endif
    #ifndef _MAX_DRIVE
    #define _MAX_DRIVE 3
    #endif
    #ifndef _MAX_DIR
    #define _MAX_DIR 256
    #endif
    #ifndef _MAX_FNAME
    #define _MAX_FNAME 256
    #endif
    #ifndef _MAX_EXT
    #define _MAX_EXT 256
    #endif

    // Path splitting (replacement for _splitpath_s)
    inline void _splitpath_s(
        const char* path,
        char* drive, size_t driveSize,
        char* dir, size_t dirSize,
        char* fname, size_t fnameSize,
        char* ext, size_t extSize)
    {
        char temp_path[_MAX_PATH];
        char temp_base[_MAX_PATH];

        // Drive is not relevant on Unix systems
        if (drive && driveSize > 0) {
            drive[0] = '\0';
        }

        // Get directory
        if (dir && dirSize > 0) {
            strcpy_s(temp_path, sizeof(temp_path), path);
            const char* dir_part = dirname(temp_path);
            strcpy_s(dir, dirSize, dir_part);
            if (strlen(dir) > 0 && dir[strlen(dir)-1] != '/') {
                strcat(dir, "/");
            }
        }

        // Get filename and extension
        if (fname || ext) {
            strcpy_s(temp_path, sizeof(temp_path), path);
            const char* base_part = basename(temp_path);
            strcpy_s(temp_base, sizeof(temp_base), base_part);

            // Find extension
            char* dot = strrchr(temp_base, '.');
            if (dot && dot != temp_base) {
                // Has extension
                if (ext && extSize > 0) {
                    strcpy_s(ext, extSize, dot);
                }
                if (fname && fnameSize > 0) {
                    *dot = '\0';  // Temporarily terminate to copy just the name
                    strcpy_s(fname, fnameSize, temp_base);
                }
            } else {
                // No extension
                if (fname && fnameSize > 0) {
                    strcpy_s(fname, fnameSize, temp_base);
                }
                if (ext && extSize > 0) {
                    ext[0] = '\0';
                }
            }
        }
    }

    // Path making (replacement for _makepath_s)
    inline void _makepath_s(
        char* path, size_t pathSize,
        const char* drive,
        const char* dir,
        const char* fname,
        const char* ext)
    {
        if (!path || pathSize == 0) return;

        path[0] = '\0';

        // Ignore drive on Unix systems

        // Add directory
        if (dir && strlen(dir) > 0) {
            strcpy_s(path, pathSize, dir);
        }

        // Add filename
        if (fname && strlen(fname) > 0) {
            strcat(path, fname);
        }

        // Add extension (add dot if not present)
        if (ext && strlen(ext) > 0) {
            if (ext[0] != '.') {
                strcat(path, ".");
            }
            strcat(path, ext);
        }
    }

#endif // !_WIN32

#endif // PLATFORM_COMPAT_H
