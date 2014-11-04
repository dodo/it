 #include "it.h"
#include "luaI.h"
#include "core-types.h"

#include "api/thread.h"
#include "api/scope.h"


void default_thread_idle(void* priv) {
    it_threads* thread = (it_threads*) priv;
    if (thread->closed || thread->ctx->err) {
        it_closes_thread(thread);
        return;
    }
    luaI_globalemit(thread->ctx->lua, "thread", "idle");
    luaI_pcall_in(thread->ctx, 2, 0);
}

void uvI_thread_idle(uv_idle_t* handle, int status) {
    it_threads* thread = (it_threads*) handle->data;
    if (!thread->ctx->err) {
        // call callback …
        thread->on_idle(thread->priv);
        return;
    }
    it_closes_thread(thread);
}

void it_runs_thread(void* priv) {
    it_threads* thread = (it_threads*) priv;
    thread->ctx->loop = uv_loop_new(); // switch context loop to thread loop
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
    luaI_getglobalfield(thread->ctx->lua, "context", "run");
    luaI_pcall_in(thread->ctx, 0, 0);
    if (!thread->ctx->err)
        // … and now run!
        uv_run(thread->ctx->loop, UV_RUN_DEFAULT);
    if (thread->ctx->err)
        printerr("thread halted: scope error: %s", thread->ctx->err);
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
    thread->thread = malloc(sizeof(uv_thread_t));
    if (!thread->thread)
        it_errors("failed to initialize thread!");
    if (uv_thread_create(thread->thread, it_runs_thread, thread))
        it_errors("uv_thread_create: failed to create thread!");
}

void it_closes_thread(it_threads* thread) {
    uv_close((uv_handle_t*) thread->idle, NULL);
    uv_stop(thread->ctx->loop);
}

void it_frees_thread(it_threads* thread) {
    if (!thread || !thread->thread) return;
    if (!thread->closed) {
        thread->closed = TRUE;
        if (uv_thread_join(thread->thread))
            it_errors("uv_thread_join: failed to join thread!");
    }
    free(thread->thread);
    thread->thread = NULL;
    thread->ctx->free = TRUE; // now we can
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