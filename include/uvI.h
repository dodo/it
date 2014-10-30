#ifndef UVI_H
#define UVI_H

#include "uv.h"


#define uvI_dlsym(lib, name, var) \
    do{ if (uv_dlsym(lib,name, (void**) (var))) \
        uvI_dlerror(lib, "uv_dlsym: failed to sym "name); \
    } while (0)


uv_lib_t* uvI_dlopen(const char* filename);


#endif /* UVI_H */