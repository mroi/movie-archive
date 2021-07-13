/* For sandboxed applications (which the XPC converter is), dlopen ignores
 * library paths passed by environment variables. We therefore have to intercept
 * the dlopen() call from libdvdread with our own implementation, adjust the
 * requested path and then forward that to the actual dlopen() in libSystem. */

#include <string.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <limits.h>
#include <libgen.h>

#include "intercept.h"

#define LIBDVDCSS "libdvdcss.2.dylib"


void *dlopen(const char* path, int mode)
{
	ORIGINAL_SYMBOL(dlopen, (const char* path, int mode))

	// when trying to load libdvdcss, fixup path so it is found
	if (strcmp(path, LIBDVDCSS) == 0) {

		// fetch path of current executable
		Dl_info info;
		int result_dladdr = dladdr((void *)dlopen, &info);
		assert(result_dladdr && info.dli_fname);

		// replace library name with libdvdcss
		char dvdcss_path[PATH_MAX + 1];
		assert(strlen(info.dli_fname) <= PATH_MAX);
		char *result_dirname = dirname_r(info.dli_fname, dvdcss_path);
		assert(result_dirname && result_dirname == dvdcss_path);
		size_t len = strlcat(dvdcss_path, "/" LIBDVDCSS, sizeof(dvdcss_path));
		assert(len < sizeof(dvdcss_path));

		return (void *)original_dlopen(dvdcss_path, mode);
	}

	return (void *)original_dlopen(path, mode);
}
