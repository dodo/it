 #ifndef API_H
#define API_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include <uv.h>
#include <lua.h>


#include "it-types.h"


extern int register_api(lua_State* L, const char *name);
extern int api_version(lua_State* L);


#endif /* API_H */