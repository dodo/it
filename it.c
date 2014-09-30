#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <signal.h>
#include <unistd.h>

#include "it-types.h"
#include "luaI.h"


static void sigint_cb(uv_signal_t* handle, int signum) {
    uv_stop(handle->loop);
    uv_signal_stop(handle);
}

int main(int argc, char *argv[]) {
    signal(SIGPIPE, SIG_IGN);

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
    if (process.exit_code == -1)
        uv_run(ctx.loop, UV_RUN_DEFAULT);
    // shutdown
    lua_close(ctx.lua);
    return process.exit_code;
}
