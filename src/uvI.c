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
    size_t size = 2*PATH_MAX;
    char exec_path[2*PATH_MAX];
    if (uv_exepath(exec_path, &size))
        it_errors("uv_exepath: failed to get execpath");
    int offset = size - 1;
    while (exec_path[offset] != '/') offset--;
    strcpy(((char*) (&exec_path) + offset + 1), filename);
    const char* filepath = (const char*) &exec_path;
    if(uv_dlopen(filepath, lib))
        uvI_dlerror(lib, "uv_dlopen: failed to open %s", filepath);
    return lib;
}
