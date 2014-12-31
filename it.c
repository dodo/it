#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>

#include "it-types.h"
#include "luaI.h"
#include "uvI.h"
#include "it.h"


static void sigint_cb(uv_signal_t* handle, int signum) {
    uv_stop(handle->loop);
}

bool initialized = FALSE;
#if UV_VERSION_MAJOR == 0 && UV_VERSION_MINOR == 10 // libuv 0.10
static void init_cb(uv_idle_t* handle, int status) {
#elif UV_VERSION_MAJOR >= 1 // libuv >=1.0
static void init_cb(uv_idle_t* handle) {
#endif
    lua_State* L = (lua_State*) handle->data;
    if (initialized) { // loop …
        luaI_getglobalfield(L, "process", "loop");
        luaI_pcall(L, 0, 0, TRUE);
    } else { // finalize initialization …
        initialized = TRUE;
        if (lua_isnil(L, -1)) {
            uv_idle_stop(handle);
            return;
        }
        // if function returned when called for the first time, call it all the time
        luaI_pcall(L, 0, 1, TRUE);
        // if function was returned we declare it as loop
        if(lua_isfunction(L, -1)) {
            luaI_setglobalfield(L, "process", "loop");
        } else {
            uv_idle_stop(handle);
        }
    }
}

int main(int argc, char *argv[]) {
    uv_idle_t init;
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
    if (!luaI_createstate(&process)) {
        // nothing to call!
        return 1;
    }
    // make sure we uv_run at least once
    uv_idle_init(ctx.loop, &init);
    init.data = ctx.lua;
    uv_idle_start(&init, init_cb);
    // run forest run!
    if (process.exit_code == -1) {
        process.exit_code = 0;
        uv_run(ctx.loop, UV_RUN_DEFAULT);
    }
    // shutdown
    luaI_close(ctx.lua, "process", process.exit_code);
    //
    uv_signal_stop(process.sigint);
    process.sigint = NULL;
    // return exit code set by lua
    return process.exit_code;
}
