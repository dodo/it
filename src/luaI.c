#include "luaI.h"

#include "it.h"


#include "lua/it.h"
static const luaL_Reg luaI_reg_it[] = {
    {"boots", it_boots_lua},
    {"forks", it_forks_lua},
    {NULL, NULL}
};

#include "lua/ctx.h"
static const luaL_Reg luaI_reg_ctx[] = {
    {"import", it_imports_ctx_lua},
    {"call", it_calls_ctx_lua},
    {"__gc", it_kills_ctx_lua},
    {NULL, NULL}
};


static int buf_writer(lua_State* L, const void* b, size_t n, void* B) {
  (void)L;
  luaL_addlstring((luaL_Buffer*) B, (const char *)b, n);
  return 0;
}

int luaI_copyfunction(lua_State* L, lua_State* src) {
    char const* name = NULL;
    size_t sz;
    luaL_Buffer b;
    luaL_buffinit(src, &b);
    if (lua_dump(src, buf_writer, &b)) {
        return luaL_error(src, "internal error: function dump failed.");
    }
    luaL_pushresult(&b);
    char const* s = lua_tolstring(src, -1, &sz);
    if (luaL_loadbuffer(L, s, sz, name)) {
        puts("fail loadbuffer");
        return lua_error(L);
    }
    lua_pop(src, 2); // dumped string + function
    return 0;
}

int luaI_dofile(lua_State* L, const char *filename) {
    if (luaL_dofile(L, filename)) {
        return lua_error(L);
    }
    return 0;
}

it_processes* luaI_getprocess(lua_State* L) {
    luaI_getglobalfield(L, "_it", "process");
    it_processes* process = lua_touserdata(L, -1);
    lua_pop(L, 1);
    return process;
}

it_states* luaI_getstate(lua_State* L) {
    lua_getglobal(L, "__it_states__");
    it_states* state = lua_touserdata(L, -1);
    lua_pop(L, 1);
    return state;
}

int luaI_setstate(lua_State* L, it_states* ctx) {
    size_t size = 2*PATH_MAX;
    char exec_path[2*PATH_MAX];
    if (uv_exepath(exec_path, &size)) {
        uv_err_t err = uv_last_error(ctx->loop);
        return luaL_error(L, "uv_exepath: %s", uv_strerror(err));
    }
    lua_pushlightuserdata(L, ctx);
    lua_setglobal(L, "__it_states__");
    luaL_loadstring(L,
        "package.path = ("
            "table.concat({...}, ';')" // concat arguments
            ":match('^(.*)/[^/]+$')"   // remove executable name
            " .. '/lib/core/?.lua'"    // append core lib path
        ") .. ';' .. package.path");   // prepend to lua search paths
    lua_pushlstring(L, exec_path, size);
    lua_call(L, 1, 0);
    return 0;
}

int luaI_newstate(it_states* ctx) {
    // create lua state
    lua_State* L = luaL_newstate();
    if (!L) {
        fprintf(stderr, "failed to allocate lua state!\n");
        return 1;
    }
    ctx->lua = L;
    // load lua libs
    luaL_openlibs(L);
    luaI_newmetatable(L, "Context", luaI_reg_ctx);
    lua_pop(L,1); // dont need metatable right now
    if (luaI_setstate(L, ctx)) {
        fprintf(stderr, "failed to initialize lua state!\n");
        return 1;
    }
    return 0;
}

int luaI_createstate(it_processes* process) {
    it_states* ctx = process->ctx;
    if (luaI_newstate(ctx)) {
        return 1;
    }
    luaI_newlib(ctx->lua, "_it", luaI_reg_it);
    lua_pushlightuserdata(ctx->lua, process);
    luaI_setglobalfield(ctx->lua, "_it", "process");
    luaI_dofile(ctx->lua, "lib/initrd.lua");
    return 0;
}