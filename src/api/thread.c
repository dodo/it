#include "it.h"
#include "uvI.h"
#include "luaI.h"
#include "core-types.h"

#include "api/thread.h"
#include "api/scope.h"

#include <poll.h>


it_threads* it_allocs_thread() {
    it_threads* thread = (it_threads*) calloc(1, sizeof(it_threads));
    if (!thread)
        it_errors("calloc(1, sizeof(it_threads)): failed to allocate thread");
    thread->refc = 1;
    return thread;
}

void default_thread_idle(void* priv) {
    it_threads* thread = (it_threads*) priv;
    if (thread->closed) {
        it_stops_thread(thread);
        return;
    }
    luaI_getglobalfield(thread->ctx->lua, "process", "context");
    luaI_localemit(thread->ctx->lua, "thread", "idle");
    luaI_pcall_in(thread->ctx, 2, 1);
//     it_collectsgarbage_scope(thread->ctx);
    if (!lua_toboolean(thread->ctx->lua, -1)) {
        // no 'need render' event listener, so we wait here
        poll(NULL, 0, 2); // ms
    }
    lua_pop(thread->ctx->lua, 1); // emit return value
}

#if UV_VERSION_MAJOR == 0 && UV_VERSION_MINOR == 10 // libuv 0.10
void uvI_thread_idle(uv_idle_t* handle, int status) {
#elif UV_VERSION_MAJOR >= 1 // libuv >=1.0
void uvI_thread_idle(uv_idle_t* handle) {
#endif
    it_threads* thread = (it_threads*) handle->data;
    if (thread && (!thread->ctx || (thread->ctx && thread->ctx->err))) {
        it_stops_thread(thread);
        return;
    }
    // call callback …
    if (thread && thread->on_idle)
        thread->on_idle(thread->priv);
    else poll(NULL, 0, 2); // ms
}

void it_runs_thread(void* priv) {
    it_threads* thread = (it_threads*) priv;
    if (thread->closed) return;
    if (!thread->loop) {
#if UV_VERSION_MAJOR == 0 && UV_VERSION_MINOR == 10 // libuv 0.10
        thread->loop = uv_loop_new(); // switch context loop to thread loop
#elif UV_VERSION_MAJOR >= 1 // libuv >=1.0
        int err;
        thread->loop = (uv_loop_t*) malloc(sizeof(uv_loop_t));
        if (!thread->loop)
            it_errors("failed to create loop in thread %d!",
                uvI_thread_pool_index(pthread_self()));
        if ((err = uv_loop_init(thread->loop)))
            uvI_error(thread->loop, err, "%s uv_loop_init: %s");
#endif
    }
    uv_idle_t idle;
    thread->idle = &idle;
    uv_idle_init(thread->loop, thread->idle);
    thread->idle->data = thread;
    uv_idle_start(thread->idle, uvI_thread_idle);
    // call callback …
    if (thread->on_init) {
        thread->on_init(thread->priv);
        thread->on_init = NULL;
    }
    // … then call into lua state first …
    it_calls_scope(thread->ctx);
    int idx = uvI_thread_pool_index(pthread_self());
    if (!thread->ctx->err)
        // … and now run!
        uv_run(thread->loop, UV_RUN_DEFAULT);
    if (thread->ctx->err)
        printerr("thread %d halted: scope error: %s", idx, thread->ctx->err);
    it_closes_thread(thread);
}

void it_inits_thread(it_threads* thread, it_states* ctx) {
    if (!thread) return;
    if (!ctx) return;
    if (thread->thread) return;
    if (thread->ctx) it_frees_scope(thread->ctx);
    thread->ctx = NULL;
    if (!ctx->refc) return;
    thread->ctx = ctx;
    it_refs((it_refcounts*) ctx);
    thread->closed = FALSE;
    thread->on_idle = default_thread_idle;
    thread->priv = thread;
}

void it_creates_thread(it_threads* thread) {
    if (!thread) return;
    if (thread->thread) return;
    if (!thread->ctx) it_errors("thread has no lua scope");
    if (!thread->on_idle) it_errors("thread has no idle callback");
    // now start the thread to run the encoder
    uvI_thread_t* uvthread = uvI_thread_new();
    if (!uvthread)
        it_errors("failed to initialize thread!");
    thread->thread = &(uvthread->pthread);
    uvthread->safe = thread->ctx->safe;
    if (uvI_thread_create(uvthread, it_runs_thread, thread)) {
        thread->thread = NULL;
        uvI_thread_free(uvthread);
        it_errors("uv_thread_create: failed to create thread %d!",
                uvI_thread_pool_index(uvthread->pthread));
    }
}

void it_safes_thread(it_threads* thread, bool safe) {
    // TODO change lua_assert here as well?
    if (!thread || !thread->thread) return;
    uvI_thread_t* uvthread = uvI_thread_pool(*(thread->thread));
    if (!uvthread) return;
    uvthread->safe = safe;
}

void it_joins_thread(it_threads* thread) {
    if (!thread) return;
    if (!thread->thread) return;
    uv_thread_t* uvthread = thread->thread;
    if (uvthread) {
        thread->thread = NULL;
        it_closes_thread(thread);
        if (uvthread && uv_thread_join(uvthread))
            it_errors("uv_thread_join: failed to join thread %d!",
                ((!uvthread) ? -1 : uvI_thread_pool_index(*uvthread)));
    }
    if (uvthread) uvI_thread_free(uvI_thread_pool(*uvthread));
    if (thread->loop) {
        uvI_loop_delete(thread->loop);
        thread->loop = NULL;
    }
    // cache and clear those values before triggering any callbacks …
    uvI_thread_callback on_free = thread->on_free;
    thread->on_init = NULL;
    thread->on_idle = NULL;
    thread->on_free = NULL;
    // call callbacks …
    if (on_free) on_free(thread->priv);
    thread->priv = NULL;
}

void it_stops_thread(it_threads* thread) {
    if (!thread) return;
    if (thread->idle) {
        uv_idle_t* idle = thread->idle;
        thread->idle = NULL;
        uv_close((uv_handle_t*) idle, NULL);
        if (thread->ctx && thread->ctx->lua && !thread->ctx->err) {
            luaI_getglobalfield(thread->ctx->lua, "process", "context");
            luaI_localemit(thread->ctx->lua, "thread", "stop");
            luaI_pcall_in(thread->ctx, 2, 0);
        }
    }
    if (thread->loop) {
        uv_stop(thread->loop);
    }
}

void it_closes_thread(it_threads* thread) {
    if (!thread) return;
    thread->closed = TRUE;
    it_stops_thread(thread);
}

void it_frees_thread(it_threads* thread) {
    if (!thread) return;
    if (it_unrefs((it_refcounts*) thread) > 0) return;
    it_joins_thread(thread);
    if (thread->ctx) {
        it_frees_scope(thread->ctx);
        thread->ctx = NULL;
    }
    if (!thread->refc)
        free(thread);
}
