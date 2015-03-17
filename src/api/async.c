 #include "it.h"
#include "luaI.h"

#include "api/async.h"
#include "api/thread.h"


it_asyncs* it_allocs_async() {
    it_asyncs* async = (it_asyncs*) calloc(1, sizeof(it_asyncs));
    if (!async)
        it_errors("calloc(1, sizeof(it_asyncs)): failed to allocate async event emitter");
    async->refc = 1;
    return async;
}

void default_async_callback(void* priv, it_queues* queue) {
    it_asyncs* async = (it_asyncs*) priv;
//     if (async->thread->ctx->closed) return;
    luaI_getglobalfield(async->thread->ctx->lua, "process", "context");
    luaI_localemit(async->thread->ctx->lua, "async", queue->key);
    int nargs = 2 + luaI_pushqueuevalues(async->thread->ctx->lua, queue);
    luaI_pcall_in(async->thread->ctx, nargs, 0);
}

#if UV_VERSION_MAJOR == 0 && UV_VERSION_MINOR == 10 // libuv 0.10
void uvI_async_call(uv_async_t* handle, int status) {
#elif UV_VERSION_MAJOR >= 1 // libuv >=1.0
void uvI_async_call(uv_async_t* handle) {
#endif
    it_asyncs* async = (it_asyncs*) handle->data;
    // clear queue …
    uv_mutex_lock(async->mutex);
    it_queues* queue = async->queue;
    async->queue = NULL;
    async->last = NULL;
    uv_mutex_unlock(async->mutex);
    // work queue …
    while (queue) {
        if (!async->thread->ctx || (async->thread->ctx && async->thread->ctx->err)) break;
        async->on_sync(async->priv, queue);
        it_queues* next = queue->next;
        queue->next = NULL; // disable cascade free
        it_frees_queue(queue);
        queue = next;
    }
}

void it_inits_async(it_asyncs* async) {
    if (!async) return;
    if (!async->thread) it_errors("thread required");
    async->priv = async;
    async->on_sync = default_async_callback;
    if (!async->async) {
        uv_async_t* uvasync = (uv_async_t*) malloc(sizeof(uv_async_t));
        if (!uvasync) return;
        async->async = uvasync;
        uv_async_init(async->thread->loop, uvasync, uvI_async_call);
        uvasync->data = async;
    }
    if (!async->mutex) {
        uv_mutex_t* uvmutex = (uv_mutex_t*) malloc(sizeof(uv_mutex_t));
        if (!uvmutex) return;
        async->mutex = uvmutex;
        uv_mutex_init(uvmutex);
    }
}

it_queues* it_queues_async(it_asyncs* async) {
    if (!async) return NULL; // async as arg to cascade NULL pointer
    return it_allocs_queue();
}

int it_pushes_async_lua(lua_State* L) { // (queue_userdata, value)
    it_queues*  queue = (it_queues*) lua_touserdata(L, 1);
    luaI_value* value = luaI_getvalue(L, 2);
    it_pushes_queue(queue, value);
    return 0;
}

void it_sends_async(it_asyncs* async, const char* key, it_queues* queue) {
    if (!queue || !async || !async->async) return;
    if (!async->thread || async->thread->ctx->err || async->thread->closed) return;
//     if (async->async->loop && async->async->loop->stop_flag) return;
    queue->key = key;
    // append to queue …
    uv_mutex_lock(async->mutex);
    if (async->last) {
        async->last->next = queue;
    } else {
        async->queue = queue;
    }
    async->last = queue;
    uv_mutex_unlock(async->mutex);
    // trigger whateva thread
    uv_async_send(async->async);
}

void it_frees_async(it_asyncs* async) {
    if (!async) return;
    if (it_unrefs((it_refcounts*) async) > 0) return;
    it_queues* queue = async->queue;
    async->queue = NULL;
    async->last = NULL;
    it_frees_queue(queue);
    if (async->async) {
        uv_async_t* uvasync = async->async;
        async->async = NULL;
        uvasync->data = NULL;
        // might take a while …
        uv_close((uv_handle_t*) uvasync, NULL);
        free(uvasync);
    }
    if (async->mutex) {
        uv_mutex_t* mutex = async->mutex;
        async->mutex = NULL;
        // might take a while …
        uv_mutex_destroy(mutex);
        free(mutex);
    }
}
