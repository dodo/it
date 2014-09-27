#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

#include <uv.h>

#include <lua.h>
#include <lauxlib.h>


typedef struct {
    uv_loop_t *loop;
    uv_signal_t *sigint;
    lua_State *lua;
    int argc; char **argv;
    int exit_code;
} it_states;


static void sigint_cb(uv_signal_t* handle, int signum) {
    uv_stop(handle->loop);
    uv_signal_stop(handle);
}

int luaI_setstate(lua_State* L, void* state, uv_loop_t *loop) {
    size_t size = 2*PATH_MAX;
    char exec_path[2*PATH_MAX];
    if (uv_exepath(exec_path, &size)) {
        uv_err_t err = uv_last_error(loop);
        return luaL_error(L, "uv_exepath: %s", uv_strerror(err));
    }
    lua_pushlightuserdata(L, state);
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

it_states* luaI_getstate(lua_State* L) {
    lua_getglobal(L, "__it_states__");
    it_states* state = lua_touserdata(L, -1);
    lua_pop(L, 1);
    return state;
}

int it_gets_cwd_lua(lua_State* L) {
    lua_pushstring(L, getcwd(NULL, 0)); // thanks to gnu c
    return 1;
}

int it_exits_lua(lua_State* L) {
    it_states* state = luaI_getstate(L);
    int code = 0;
    if (lua_gettop(L))
        code = luaL_checkint(L, 1);
    state->exit_code = code;
    uv_stop(state->loop);
    return 0;
}

int it_boots_lua(lua_State* L) {
    it_states* state = luaI_getstate(L);
    // process.argv
    lua_createtable(L, state->argc, 0);
    int i; for (i = 0; i < state->argc; i++) {
        lua_pushstring(L, state->argv[i]);
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

int main(int argc, char *argv[]) {
    it_states state;
    // default state values
    state.argc = argc;
    state.argv = argv;
    state.exit_code = -1;
    state.loop = uv_default_loop();
    // init signals
    uv_signal_t sigint_signal;
    state.sigint = &sigint_signal;
    // start signal watchers
    uv_signal_init(state.loop, state.sigint);
    uv_signal_start(state.sigint, sigint_cb, SIGINT);

    // create lua state
    state.lua = luaL_newstate();
    if (!state.lua) {
        fprintf(stderr, "failed to allocate lua state!\n");
        exit(1);
    }
    // load lua libs
    luaL_openlibs(state.lua);
    luaI_setstate(state.lua, &state, state.loop);
    // c entry point after first lua call
    lua_pushcfunction(state.lua, &it_boots_lua);
    lua_setglobal(state.lua, "__it_boots");

    // load lua kernel
    if (luaL_loadfile(state.lua, "lib/initrd.lua")) {
        fprintf(stderr, "failed to load lua kernel: %s\n", lua_tostring(state.lua, -1));
        exit(1);
    }
    // boot lua
    lua_call(state.lua, 0, 0);
    // run forest run!
    if (state.exit_code == -1)
        uv_run(state.loop, UV_RUN_DEFAULT);
    // shutdown
    lua_close(state.lua);
    return state.exit_code;
}
