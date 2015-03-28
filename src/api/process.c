#include "it.h"
#include "luaI.h"


#include "api/process.h"
#include "api/scope.h"
#include "api/queue.h"

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
    uvI_thread_t* thread = NULL;
    if (process->runsinthread) thread = uvI_thread_tmp();
    if (initialized) { // loop …
        int argc = process->multireturn ? LUA_MULTRET : 0;
        it_resets_queue(process->queue); // free results from last time
        luaI_getglobalfield(process->ctx->lua, "process", "main");
        luaI_pcall(process->ctx->lua, 0, argc, TRUE/*safe*/);
        if (argc) {
            int nargs = lua_gettop(process->ctx->lua);
            int i; for (i = 0; i < nargs; i++) {
                luaI_value* value = luaI_getvalue(process->ctx->lua,
                                              i - nargs);
                it_pushes_queue(process->queue, value);
            }
            lua_pop(process->ctx->lua, nargs);
        }
    } else { // finalize initialization …
        luaI_getglobalfield(process->ctx->lua, "process", "boot");
        if (!lua_isfunction(process->ctx->lua, -1)) {
            if (thread) uvI_thread_free(thread);
            lua_pop(process->ctx->lua, 1);
            process->init = NULL;
            uv_idle_stop(handle);
            return;
        }
        initialized = TRUE;
        // if function returned when called for the first time, call it all the time
        luaI_pcall(process->ctx->lua, 0, 1, 2/*super safe*/);
        // if function was returned we declare it as loop
        if(lua_isfunction(process->ctx->lua, -1)) {
            luaI_setglobalfield(process->ctx->lua, "process", "main");
        } else {
            lua_pop(process->ctx->lua, 1);
        }
        luaI_getglobalfield(process->ctx->lua, "process", "main");
        if (lua_isnil(process->ctx->lua, -1)) {
            process->init = NULL;
            uv_idle_stop(handle);
        }
        lua_pop(process->ctx->lua, 1);
        lua_pushnil(process->ctx->lua); // dont remove this line!
    }
    if (thread) uvI_thread_free(thread);
}

it_processes* it_allocs_process() {
    it_processes* process = (it_processes*) calloc(1, sizeof(it_processes));
    if (!process)
        it_errors("calloc(1, sizeof(it_processes)): failed to allocate process");
    process->refc = 0; // increased in luaI_setprocess
    process->exit_code = -1;
    process->multireturn = FALSE;
    process->runsinthread = FALSE;
    return process;
}

void it_creates_process(it_processes* process) {
    if (!process) return;
    process->ctx = it_allocs_scope();
    if (!process->ctx) return;
    process->queue = it_allocs_queue();
    if (!process->queue) return;
    process->ctx->name = "process.scope";
    process->loop = uv_default_loop();
    it_sigints_process(process);
    uvI_init();
}

void it_inits_process(it_processes* process) {
    if (!process) return;
    // hopefully called right after dofile('initrd.lua')
    if (!lua_isfunction(process->ctx->lua, -1)) {
        // nothing to do …
        return;
    }
    luaI_getglobalfield(process->ctx->lua, "process", "boot");
    if (lua_isfunction(process->ctx->lua, -1)) {
        lua_pop(process->ctx->lua, 1);
        luaI_setglobalfield(process->ctx->lua, "process", "c_boot_function");
    } else {
        lua_pop(process->ctx->lua, 1);
        luaI_setglobalfield(process->ctx->lua, "process", "boot");
    }
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

void it_shutdowns_process(it_processes* process) {
    if (!process) return;
    // shutdown
    it_closes_process(process);
    it_closes_scope(process->ctx);
    it_frees_process(process);
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
}

void it_frees_process(it_processes* process) {
    if (!process) return;
    if (it_unrefs((it_refcounts*) process) > 0) return;
    // shutdown
    it_closes_process(process);
    it_closes_scope(process->ctx);
    it_frees_scope(process->ctx);
    it_frees_queue(process->queue);
    if (!process->refc) // just to be sure
        free(process);
}

// borrowed from luasocket (socket.gettime)
double it_gets_time_process() {
    struct timeval v;
    gettimeofday(&v, (struct timezone *) NULL);
    /* Unix Epoch time (time since January 1, 1970 (UTC)) */
    return (double)(v.tv_sec + v.tv_usec / (long int)1.0e6);
}

static int lua_api_run(lua_State* L) {
    // luaI_parsearguments execution before lua_api_run is excpected
    it_processes* process = luaI_getprocess(L);
    if (!process) return 0;
    if (uv_run(process->loop, UV_RUN_NOWAIT)) {
        int argc = process->queue->count;
        luaI_pushqueuevalues(process->ctx->lua, process->queue);
        it_resets_queue(process->queue);
        return argc;
    } else {
        it_shutdowns_process(process);
        luaI_setprocess(L, NULL);
        process = NULL;
        lua_pushnil(L);
    }
    return 1;
}

int it_runs_process(lua_State* L, int argc, char *argv[]) {
    it_processes* process = it_allocs_process();
    if (!process) return 1;
    // default state values
    process->argc = argc;
    process->argv = argv;
    process->islibrary = L ? TRUE : FALSE;
    // create lua state
    if (!luaI_createstate(L, process)) {
        // nothing to call!
        it_shutdowns_process(process);
        return 1;
    }
    // return earlier to let the original lua state patch some stuff first
    // (eg process.argv)
    if (L) {
        process->multireturn = TRUE;
        lua_pushcfunction(L, lua_api_run);
        return 0;
    }
    // determine if action of lua result
    if (process->exit_code == -1) {
        process->exit_code = 0;
        // run forest run!
        uv_run(process->loop, UV_RUN_DEFAULT);
    }
    int exit_code = process->exit_code;
    it_shutdowns_process(process);
    // return exit code set by lua
    return exit_code;
}
