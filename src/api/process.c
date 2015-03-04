#include "it.h"
#include "luaI.h"


#include "api/process.h"
#include "api/scope.h"

static bool killed = FALSE;
static void sigint_cb(uv_signal_t* handle, int signum) {
    killed = TRUE;
    uv_stop(handle->loop);
}

static bool initialized = FALSE;
#if UV_VERSION_MAJOR == 0 && UV_VERSION_MINOR == 10 // libuv 0.10
static void init_cb(uv_idle_t* handle, int status) {
#elif UV_VERSION_MAJOR >= 1 // libuv >=1.0
static void init_cb(uv_idle_t* handle) {
#endif
    it_processes* process = (it_processes*) handle->data;
    if (initialized) { // loop …
        luaI_getglobalfield(process->ctx->lua, "process", "main");
        luaI_pcall(process->ctx->lua, 0, 0, TRUE/*safe*/);
    } else { // finalize initialization …
        initialized = TRUE;
        if (lua_isnil(process->ctx->lua, -1)) {
            process->init = NULL;
            uv_idle_stop(handle);
            return;
        }
        // if function returned when called for the first time, call it all the time
        luaI_pcall(process->ctx->lua, 0, 1, 2/*super safe*/);
        // if function was returned we declare it as loop
        if(lua_isfunction(process->ctx->lua, -1)) {
            luaI_setglobalfield(process->ctx->lua, "process", "main");
        }
        luaI_getglobalfield(process->ctx->lua, "process", "main");
        if (lua_isnil(process->ctx->lua, -1)) {
            process->init = NULL;
            uv_idle_stop(handle);
        }
        lua_pop(process->ctx->lua, 1);
    }
}

void it_creates_process(it_processes* process) {
    if (!process) return;
    process->ctx = it_allocs_scope();
    if (!process->ctx) return;
    process->loop = uv_default_loop();
    it_sigints_process(process);
    uvI_init();
}

void it_inits_process(it_processes* process) {
    if (!process) return;
    uv_idle_t* init = (uv_idle_t*) malloc(sizeof(uv_idle_t));
    if (!init) it_errors("malloc(sizeof(uv_idle_t)): failed to create process init handle");
    // make sure we uv_run at least once
    uv_idle_init(process->loop, init);
    init->data = process;
    uv_idle_start(init, init_cb);
}

void it_sigints_process(it_processes* process) {
    if (!process) return;
    // init signals
    uv_signal_t* sigint = (uv_signal_t*) malloc(sizeof(uv_signal_t));
    if (!sigint) it_errors("malloc(sizeof(uv_signal_t)): failed to create SIGINT handle");
    process->sigint = sigint;
    // start signal watchers
    uv_signal_init(process->loop, sigint);
    uv_signal_start(sigint, sigint_cb, SIGINT);
}

void it_exits_process(it_processes* process, int code) {
    if (!process) return;
    if (code) process->exit_code = code;
    if (killed || !process->sigint) return;
    killed = TRUE; // before we actually kill, so we dont clash with panic callbacks
    uv_kill(getpid(), SIGINT); // step out of current lua scope
    return;
}

void it_closes_process(it_processes* process) {
    if (!process) return;
    if (process->init) {
        uv_idle_t* init = process->init;
        process->init = NULL;
        // might take a while …
        uv_idle_stop(init);
    }
    if (process->sigint) {
        uv_signal_t* sigint = process->sigint;
        process->sigint = NULL;
        // might take a while …
        uv_signal_stop(sigint);
    }
    // shutdown
    it_frees_scope(process->ctx);
}

// borrowed from luasocket (socket.gettime)
double it_gets_time_process() {
    struct timeval v;
    gettimeofday(&v, (struct timezone *) NULL);
    /* Unix Epoch time (time since January 1, 1970 (UTC)) */
    return v.tv_sec + v.tv_usec/1.0e6;
}
