#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <signal.h>
#include <unistd.h>

#include "it-types.h"
#include "luaI.h"
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

void load_api() {
    static int loaded = 0;
    if (loaded) return;
    loaded = 1;
    uv_lib_t* api = malloc(sizeof(uv_lib_t));
    if (!api) it_errors("malloc(sizeof(uv_lib_t)): failed to create");
    size_t size = 2*PATH_MAX;
    char exec_path[2*PATH_MAX];
    if (uv_exepath(exec_path, &size))
        it_errors("uv_exepath: failed to get execpath");
    int offset = size - 1;
    while (exec_path[offset] != '/') offset--;
    strcpy(((char*) (&exec_path) + offset + 1), "lib/api.so\0");
    const char* api_filename = (const char*) &exec_path;
    if(uv_dlopen(api_filename, api))
        it_errors("uv_dlopen: failed to open %s (%s)",
                  api_filename, uv_dlerror(api));
    // finally load functions …
    if (uv_dlsym(api, "luaI_createstate", (void**) &luaI_createstate))
        it_errors("uv_dlsym: failed to sym luaI_createstate (%s)",
                  uv_dlerror(api));
    if (uv_dlsym(api, "luaI_close", (void**) &luaI_close))
        it_errors("uv_dlsym: failed to sym luaI_close (%s)",
                  uv_dlerror(api));
}

int main(int argc, char *argv[]) {
    signal(SIGPIPE, SIG_IGN);
    load_api();

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
