#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

#include <uv.h>

#include <luajit.h>
#include <lualib.h>
#include <lauxlib.h>


#ifndef luaL_newlib
    // these are missing in luajit but defined in lua > 5.2
    #define luaL_setfuncs(L,l,n) \
        luaL_register(L,NULL,l)

    #define luaL_newlibtable(L,l) \
        lua_createtable(L, 0, sizeof(l)/sizeof((l)[0]) - 1)

    #define luaL_newlib(L,l) \
        (luaL_newlibtable(L,l), luaL_setfuncs(L,l,0))
#endif

#define luaI_newlib(L,name,l) \
    (luaL_newlib(L,l), lua_setglobal(L,name))

#define luaI_newmetatable(L,name,l) \
    do {if (luaL_newmetatable(L,name)) { \
        luaL_newlib(L,l); \
        lua_setfield(L, -2, "__index"); \
    }} while (0)

#define luaI_setmetatable(L,name) \
    (luaL_getmetatable(L,name), lua_setmetatable(L,-2))

#define luaI_getglobalfield(L,gn,fn) \
    (lua_getglobal(L,gn), lua_getfield(L,-1,fn), lua_remove(L,-2))

#define luaI_setglobalfield(L,gn,fn) \
    (lua_getglobal(L,gn), lua_pushvalue(L,-2), lua_setfield(L,-2,fn), lua_pop(L,2))


typedef struct {
    lua_State *lua;
    uv_loop_t *loop;
} it_states;


typedef struct {
    it_states *ctx;
    uv_signal_t *sigint;
    int argc; char **argv;
    int exit_code;
} it_processes;

static void sigint_cb(uv_signal_t* handle, int signum) {
    uv_stop(handle->loop);
    uv_signal_stop(handle);
}

int it_runs_ctx(it_states* ctx) {
    luaI_getglobalfield(ctx->lua, "context", "run");
    if (lua_pcall(ctx->lua, 0, 0, 0)) {
        return lua_error(ctx->lua);
    }
    return 0;
}

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

int luaI_dofile(lua_State* L, const char *filename) {
    if (luaL_dofile(L, filename)) {
        return lua_error(L);
    }
    return 0;
}

int it_gets_cwd_lua(lua_State* L) {
    lua_pushstring(L, getcwd(NULL, 0)); // thanks to gnu c
    return 1;
}

int it_exits_lua(lua_State* L) {
    it_processes* process = luaI_getprocess(L);
    int code = 0;
    if (lua_gettop(L))
        code = luaL_checkint(L, 1);
    process->exit_code = code;
    uv_stop(process->ctx->loop);
    return 0;
}

int it_boots_lua(lua_State* L) {
    it_processes* process = luaI_getprocess(L);
    // process.argv
    lua_createtable(L, process->argc, 0);
    int i; for (i = 0; i < process->argc; i++) {
        lua_pushstring(L, process->argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setfield(L, -2, "argv");
    // process.exit
    lua_pushcfunction(L, it_exits_lua);
    lua_setfield(L, -2, "exit");
    // process.cwd
    lua_pushcfunction(L, it_gets_cwd_lua);
    lua_setfield(L, -2, "cwd");
    // process.pid
    lua_pushinteger(L, getpid());
    lua_setfield(L, -2, "pid");
    return 0;
}

int it_imports_ctx_lua(lua_State* L) {
    it_states* ctx = luaL_checkudata(L, 1, "Context");
    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_pushvalue(L, 2);
    // copy function and import into context
    luaI_getglobalfield(ctx->lua, "context", "import");
    luaI_copyfunction(ctx->lua, L);
    if (lua_pcall(ctx->lua, 1, 0, 0)) {
        return lua_error(ctx->lua);
    }
    return 0;
}

int it_calls_ctx_lua(lua_State* L) {
    it_runs_ctx(luaL_checkudata(L, 1, "Context"));
    return 0;
}

int it_kills_ctx_lua(lua_State* L) {
    it_states* ctx = luaL_checkudata(L, 1, "Context");
    lua_close(ctx->lua);
    ctx->loop = NULL;
    return 0;
}

static const luaL_Reg luaI_reg_ctx[] = {
    {"import", it_imports_ctx_lua},
    {"call", it_calls_ctx_lua},
    {"__gc", it_kills_ctx_lua},
    {NULL, NULL}
};

lua_State* luaI_newstate(it_states* ctx) {
    // create lua state
    lua_State* L = luaL_newstate();
    if (!L) {
        fprintf(stderr, "failed to allocate lua state!\n");
        return NULL;
    }
    // load lua libs
    luaL_openlibs(L);
    luaI_newmetatable(L, "Context", luaI_reg_ctx);
    lua_pop(L,1); // dont need metatable right now
    if (luaI_setstate(L, ctx)) {
        fprintf(stderr, "failed to initialize lua state!\n");
        return NULL;
    }
    return L;
}

int it_forks_lua(lua_State* L) {
    it_states* ctx;
    it_states* state = luaI_getstate(L);
    ctx = lua_newuserdata(L, sizeof(it_states));
    ctx->loop = state->loop;
    ctx->lua = luaI_newstate(ctx);
    luaI_setmetatable(L, "Context");
    lua_createtable(ctx->lua, 0, 1);
    lua_pushcfunction(ctx->lua, it_forks_lua);
    lua_setfield(ctx->lua, -2, "forks");
    lua_setglobal(ctx->lua, "_it");
    luaI_dofile(ctx->lua, "lib/context.lua");
    return 1;
}

static const luaL_Reg luaI_reg_it[] = {
    {"boots", it_boots_lua},
    {"forks", it_forks_lua},
    {NULL, NULL}
};

int main(int argc, char *argv[]) {
    it_states ctx;
    it_processes process;
    // default state values
    process.ctx = &ctx;
    process.argc = argc;
    process.argv = argv;
    process.exit_code = -1;
    ctx.loop = uv_default_loop();
    // init signals
    uv_signal_t sigint_signal;
    process.sigint = &sigint_signal;
    // start signal watchers
    uv_signal_init(ctx.loop, process.sigint);
    uv_signal_start(process.sigint, sigint_cb, SIGINT);

    // create lua state
    ctx.lua = luaI_newstate(process.ctx);
    luaI_newlib(ctx.lua, "_it", luaI_reg_it);
    lua_pushlightuserdata(ctx.lua, &process);
    luaI_setglobalfield(ctx.lua, "_it", "process");
    luaI_dofile(ctx.lua, "lib/initrd.lua");
    // run forest run!
    if (process.exit_code == -1)
        uv_run(ctx.loop, UV_RUN_DEFAULT);
    // shutdown
    lua_close(ctx.lua);
    return process.exit_code;
}
