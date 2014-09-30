#ifndef IT_H
#define IT_H

#include <uv.h>
#include <lua.h>

#include "it-types.h"

int it_runs_ctx(it_states* ctx);

int it_gets_cwd_lua(lua_State* L);

#endif /* IT_H */