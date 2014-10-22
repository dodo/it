#include "it.h"
#include "luaI.h"

#include "lua/thread.h"
#include "lua/ctx.h"


static void default_thread_init(void* priv) {
    it_threads* thread = (it_threads*) priv;
    // inject encoder handle into lua context …
    lua_pushlightuserdata(thread->ctx->lua, thread);
    lua_setglobal(thread->ctx->lua, "thread");
}

static void default_thread_callback(void* priv) {
    it_threads* thread = (it_threads*) priv;
    luaI_getglobalfield(thread->ctx->lua, "context", "emit");
    lua_getglobal(thread->ctx->lua, "context"); // self
    lua_pushstring(thread->ctx->lua, "idle");
    luaI_pcall(thread->ctx->lua, 2, 0);
    puts("default_thread_callback");
}

static void uvI_thread_idle(uv_idle_t* handle, int status) {
    it_threads* thread = (it_threads*) handle->data;
    thread->callback(thread->priv);
}

static void it_runs_thread(void* priv) {
    it_threads* thread = (it_threads*) priv;
    thread->ctx->loop = uv_loop_new(); // switch context loop to thread loop
    uv_idle_t idle;
    thread->idle = &idle;
    uv_idle_init(thread->ctx->loop, thread->idle);
    thread->idle->data = thread;
    uv_idle_start(thread->idle, uvI_thread_idle);
    if (thread->init) {
        thread->init(thread->priv);
    }
    // … then call into lua state first …
    luaI_getglobalfield(thread->ctx->lua, "context", "run");
    luaI_pcall(thread->ctx->lua, 0, 0);
    // … and now run!
    uv_run(thread->ctx->loop, UV_RUN_DEFAULT);
    thread->closed = TRUE;
}

int it_new_thread_lua(lua_State* L) { // ((optional) thread_pointer)
    if (lua_gettop(L) == 1 && lua_islightuserdata(L, 1)) {
        lua_newtable(L);
    } else {
        it_threads* thread = lua_newuserdata(L, sizeof(it_threads));
        memset(thread, 0, sizeof(it_threads));
    }
    luaI_setmetatable(L, "Thread");
    return 1;
}

int it_inits_thread_lua(lua_State* L) { // (thread_userdata, state_userdata)
    it_threads* thread = luaL_checkudata(L, 1, "Thread");
    it_states*  ctx    = luaL_checkudata(L, 2, "Context");
    ctx->free = FALSE; // take over ctx
    thread->ctx = ctx;
    thread->closed = FALSE;
    thread->init = default_thread_init;
    thread->callback = default_thread_callback;
    thread->priv = thread;
    return 0;
}

int it_creates_thread_lua(lua_State* L) { // (thread_userdata, output, settings)
    it_threads* thread = luaL_checkudata(L, 1, "Thread");
    if (thread->thread) return 0;
    if (!thread->callback) it_errors("thread has no callback");
    // now start the thread to run the encoder
    thread->thread = malloc(sizeof(uv_thread_t));
    if (!thread->thread)
        luaI_error(L, "failed to initialize thread!");
    if (uv_thread_create(thread->thread, it_runs_thread, thread))
        luaI_error(L, "uv_thread_create: failed to create thread!");
    return 0;
}

int it_kills_thread_lua(lua_State* L) { // (enc_userdata)
    it_threads* thread = luaL_checkudata(L, 1, "Thread");
    if (!thread->thread) return 0;
    if (!thread->closed) {
        thread->closed = TRUE;
        if (uv_thread_join(thread->thread))
            luaI_error(L, "uv_thread_join: failed to join thread!");
    }
    free(thread->thread);
    thread->thread = NULL;
    thread->ctx->free = TRUE; //now we can
    it_frees_ctx(thread->ctx);
    thread->ctx = NULL;
    if (thread->free) {
        thread->free(thread->priv);
    }
    thread->init = NULL;
    thread->callback = NULL;
    thread->free = NULL;
    thread->priv = NULL;
    return 0;
}
