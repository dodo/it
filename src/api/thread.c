#include "it.h"
#include "uvI.h"
#include "luaI.h"
#include "core-types.h"

#include "api/thread.h"
#include "api/scope.h"

#include <poll.h>


void default_thread_idle(void* priv) {
    it_threads* thread = (it_threads*) priv;
    if (thread->closed || thread->ctx->err) {
        it_closes_thread(thread);
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
    if (thread->ctx->err) {
        it_closes_thread(thread);
        return;
    }
    // call callback …
    thread->on_idle(thread->priv);
}

void it_runs_thread(void* priv) {
    it_threads* thread = (it_threads*) priv;
#if UV_VERSION_MAJOR == 0 && UV_VERSION_MINOR == 10 // libuv 0.10
    thread->ctx->loop = uv_loop_new(); // switch context loop to thread loop
#elif UV_VERSION_MAJOR >= 1 // libuv >=1.0
    int err;
    thread->ctx->loop = (uv_loop_t*) malloc(sizeof(uv_loop_t));
    if (!thread->ctx->loop)
        it_errors("failed to create loop in thread %d!"
            uvI_thread_pool_index(*(thread->thread)));
    if ((err = uv_loop_init(thread->ctx->loop)))
        uvI_error(thread->ctx->loop, err, "%s uv_loop_init: %s");
#endif
    uv_idle_t idle;
    thread->idle = &idle;
    uv_idle_init(thread->ctx->loop, thread->idle);
    thread->idle->data = thread;
    uv_idle_start(thread->idle, uvI_thread_idle);
    // call callback …
    if (thread->on_init) {
        thread->on_init(thread->priv);
    }
    // … then call into lua state first …
    luaI_getglobalfield(thread->ctx->lua, "process", "context");
    luaI_getlocalfield(thread->ctx->lua, "run");
    luaI_pcall_in(thread->ctx, 0, 0);
    if (!thread->ctx->err)
        // … and now run!
        uv_run(thread->ctx->loop, UV_RUN_DEFAULT);
    if (thread->ctx->err)
        printerr("thread %d halted: scope error: %s",
                uvI_thread_pool_index(*(thread->thread)),
                thread->ctx->err);
    thread->closed = TRUE;
}

void it_inits_thread(it_threads* thread, it_states* ctx) {
    if (!ctx) return;
    ctx->free = FALSE; // take over ctx
    thread->ctx = ctx;
    thread->closed = FALSE;
    thread->on_idle = default_thread_idle;
    thread->priv = thread;
}

void it_creates_thread(it_threads* thread) {
    if (thread->thread) return;
    if (!thread->on_idle) it_errors("thread has no idle callback");
    // now start the thread to run the encoder
    uvI_thread_t* uvthread = uvI_thread_new();
    if (!uvthread)
        it_errors("failed to initialize thread!");
    thread->thread = &(uvthread->pthread);
    if (uvI_thread_create(uvthread, it_runs_thread, thread))
        it_errors("uv_thread_create: failed to create thread %d!",
                uvI_thread_pool_index(uvthread->pthread));
}

void it_safes_thread(it_threads* thread, bool safe) {
    // TODO change lua_assert here as well?
    if (!thread->thread) return;
    uvI_thread_t* uvthread = uvI_thread_pool(*(thread->thread));
    if (!uvthread) return;
    uvthread->safe = safe;
}

void it_closes_thread(it_threads* thread) {
    if (thread->idle) {
        uv_idle_t* idle = thread->idle;
        thread->idle = NULL;
        uv_close((uv_handle_t*) idle, NULL);
    }
    if (thread->ctx && thread->ctx->loop) {
        uv_stop(thread->ctx->loop);
    }
}

void it_frees_thread(it_threads* thread) {
    if (!thread) return;
    // scope always referenced in itself
    if (it_unrefs((it_refcounts*) thread) > 1) return;
    if (!thread->thread) return;
    if (!thread->closed) {
        thread->closed = TRUE;
        if (uv_thread_join(thread->thread))
            it_errors("uv_thread_join: failed to join thread %d!",
                uvI_thread_pool_index(*(thread->thread)));
    }
    uvI_thread_free(uvI_thread_pool(*(thread->thread)));
    thread->thread = NULL;
    thread->ctx->free = TRUE; // now we can
    if (thread->ctx->loop) {
        uvI_loop_delete(thread->ctx->loop);
        thread->ctx->loop = NULL;
    }
    it_frees_scope(thread->ctx);
    thread->ctx = NULL;
    // call callback …
    if (thread->on_free) {
        thread->on_free(thread->priv);
    }
    thread->on_init = NULL;
    thread->on_idle = NULL;
    thread->on_free = NULL;
    thread->priv = NULL;
}
