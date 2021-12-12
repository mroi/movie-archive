/* This library replaces libSystem functions with new implementations. */

#include <stdint.h>
#include <assert.h>
#include <dlfcn.h>

#define ORIGINAL_SYMBOL(symbol, arguments) \
	static intptr_t (*original_##symbol)arguments; \
	if (!original_##symbol) { \
		Dl_info info; \
		/* retrieve internal symbol name of current function */ \
		int result = dladdr((void *)symbol, &info); \
		assert(result && info.dli_sname); \
		original_##symbol = (intptr_t (*)arguments)dlsym(RTLD_NEXT, info.dli_sname); \
		assert(original_##symbol); \
	}
