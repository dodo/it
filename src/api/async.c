 #include "it.h"
#include "luaI.h"

#include "api/async.h"
#include "api/thread.h"


void default_async_callback(void* priv, it_queues* queue) {
    it_asyncs* async = (it_asyncs*) priv;
    if (async->thread->ctx->err) return;
    luaI_getglobalfield(async->thread->ctx->lua, "process", "context");
    luaI_localemit(async->thread->ctx->lua, "async", queue->key);
    int nargs = 2 + queue->count;
    int i; for (i = 0; i < queue->count; i++) {
        luaI_value* value = queue->values[i];
        luaI_pushvalue(async->thread->ctx->lua, value);
    }
    queue->size = queue->count = 0;
    if (queue->values) {
        free(queue->values);
        queue->values = NULL;
    }
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
        async->on_sync(async->priv, queue);
        queue = queue->next;
    }
}

void it_inits_async(it_asyncs* async) {
    if (!async) return;
    uv_async_t* uvasync = (uv_async_t*) malloc(sizeof(uv_async_t));
    if (!uvasync) return;
    uv_mutex_t* uvmutex = (uv_mutex_t*) malloc(sizeof(uv_mutex_t));
    if (!uvmutex) return;
    async->async = uvasync;
    async->mutex = uvmutex;
    async->priv = async;
    async->on_sync = default_async_callback;
    // initialize uv stuff
    uv_mutex_init(uvmutex);
    uv_async_init(async->thread->ctx->loop, uvasync, uvI_async_call);
    uvasync->data = async;
}

it_queues* it_queues_async(it_asyncs* async) {
    if (!async) return NULL; // async as arg to cascade NULL pointer
    it_queues* queue = (it_queues*) calloc(1, sizeof(it_queues));
    if (!queue) return NULL;
    return queue;
}

// thread safe (hopefully *g*)
void it_pushes_async(it_queues* queue, luaI_value* value) {
    if (!queue) return;
    int pos = queue->count;
    if (++(queue->count) >= queue->size) {
        queue->size = queue->size == 0 ? 1 : 2 * queue->size;
        queue->values = realloc(queue->values, sizeof(luaI_value) * queue->size);
    }
    queue->values[pos] = value;
}

int it_pushes_async_lua(lua_State* L) { // (queue_userdata, value)
    it_queues*  queue = (it_queues*) lua_touserdata(L, 1);
    luaI_value* value = luaI_getvalue(L, 2);
    it_pushes_async(queue, value);
    return 0;
}

void it_pushes_cdata_async(it_queues* queue, void* cdata) {
    if (!queue) return;
    luaI_value* value = (luaI_value*) malloc(sizeof(luaI_value));
    if (!value) return;
    value->type = LUAI_TYPE_CDATA;
    value->v.cdata = cdata;
    it_pushes_async(queue, value);
}

void it_sends_async(it_asyncs* async, const char* key, it_queues* queue) {
    if (!async || !queue) return;
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
