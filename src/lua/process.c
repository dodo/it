#include <uv.h>

#include "it.h"
#include "luaI.h"

#include "lua/process.h"


int it_exits_process_lua(lua_State* L) { // (exit_code)
    it_processes* process = luaI_getprocess(L);
    int code = 0;
    if (lua_gettop(L) == 1 && !lua_isnil(L, 1))
        code = luaL_checkint(L, 1);
    process->exit_code = code;
    uv_kill(getpid(), SIGINT);
    return 0;
}

int it_gets_cwd_process_lua(lua_State* L) { // ()
    lua_pushstring(L, getcwd(NULL, 0)); // thanks to gnu c
    return 1;
}
