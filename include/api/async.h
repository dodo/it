#ifndef API_ASYNC_H
#define API_ASYNC_H

#include <lua.h>
#include <uv.h>


#include "it.h"
#include "api.h"
#include "luaI.h"

#include "api/async.h"
#include "api/queue.h"
#include "api/thread.h"


extern it_asyncs* it_allocs_async();

extern void default_async_callback(void* priv, it_queues* queue);
#if UV_VERSION_MAJOR == 0 && UV_VERSION_MINOR == 10 // libuv 0.10
extern void uvI_async_call(uv_async_t* handle, int status);
#elif UV_VERSION_MAJOR >= 1 // libuv >=1.0
extern void uvI_async_call(uv_async_t* handle);
#endif

extern void it_inits_async(it_asyncs* async);
extern it_queues* it_queues_async(it_asyncs* async);
extern void it_sends_async(it_asyncs* async, const char* key, it_queues* queue);
extern void it_frees_async(it_asyncs* async);

extern int it_pushes_async_lua(lua_State* L);


#endif /* API_ASYNC_H */


