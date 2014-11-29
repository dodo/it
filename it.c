#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>

#include "it-types.h"
#include "luaI.h"
#include "it.h"


static void sigint_cb(uv_signal_t* handle, int signum) {
    uv_stop(handle->loop);
}

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
    //
    uv_signal_stop(process.sigint);
    process.sigint = NULL;
    // return exit code set by lua
    return process.exit_code;
}
