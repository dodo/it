#include "it.h"
#include "luaI.h"

#include "api/process.h"


void it_exits_process(it_processes* process, int code) {
    if (!process->sigint) return;
    if (code) process->exit_code = code;
    uv_kill(getpid(), SIGINT);
    return;
}
