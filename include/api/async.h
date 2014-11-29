#ifndef API_ASYNC_H
#define API_ASYNC_H

#include <lua.h>
#include <uv.h>


#include "it.h"
#include "api.h"
#include "luaI.h"

#include "api/async.h"
#include "api/thread.h"


extern void default_async_callback(void* priv, it_queues* queue);
extern void uvI_async_call(uv_async_t* handle, int status);

extern void it_inits_async(it_asyncs* async);

extern it_queues* it_queues_async(it_asyncs* async);
extern void it_pushes_async(it_queues* queue, luaI_value* value);
extern int it_pushes_async_lua(lua_State* L);
extern void it_pushes_cdata_async(it_queues* queue, void* cdata);
extern void it_sends_async(it_asyncs* async, const char* key, it_queues* queue);

extern void it_frees_async(it_asyncs* async);


#endif /* API_ASYNC_H */


