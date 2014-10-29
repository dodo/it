#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <signal.h>
#include <unistd.h>

#include "it-types.h"
#include "luaI.h"
#include "uvI.h"
#include "it.h"


static luaI_createstate_t luaI_createstate;
static luaI_close_t luaI_close;

static void sigint_cb(uv_signal_t* handle, int signum) {
    it_processes* process = (it_processes*) handle->data;
    uv_stop(handle->loop);
    uv_signal_stop(handle);
    process->sigint = NULL;
    handle->data = NULL;
}

int main(int argc, char *argv[]) {
    signal(SIGPIPE, SIG_IGN);

    // load lua state con/de-structor …
    uv_lib_t* api = uvI_dlopen("lib/api.so");
    uvI_dlsym(api, "luaI_createstate", (void**) &luaI_createstate);
    uvI_dlsym(api, "luaI_close", (void**) &luaI_close);

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
    sigint_signal.data = &process;
    // start signal watchers
    uv_signal_init(ctx.loop, process.sigint);
    uv_signal_start(process.sigint, sigint_cb, SIGINT);
    // create lua state
    if (luaI_createstate(&process)) {
        return 1;
    }
    // run forest run!
    if (process.exit_code == -1) {
        process.exit_code = 0;
        uv_run(ctx.loop, UV_RUN_DEFAULT);
    }
    // shutdown
    luaI_close(ctx.lua, "process", process.exit_code);
    return process.exit_code;
}
