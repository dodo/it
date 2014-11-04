#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

#include "it.h"
#include "uvI.h"


uv_lib_t* uvI_dlopen(const char* filename) {
    uv_lib_t* lib = malloc(sizeof(uv_lib_t));
    if (!lib) it_errors("malloc(sizeof(uv_lib_t)): failed to create");
    if (uv_dlopen(filename, lib))
        uvI_dlerror(lib, "uv_dlopen: failed to open %s", filename);
    return lib;
}
