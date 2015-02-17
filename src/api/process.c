#include "it.h"
#include "luaI.h"

#include "api/process.h"


void it_exits_process(it_processes* process, int code) {
    if (!process->sigint) return;
    if (code) process->exit_code = code;
    uv_kill(getpid(), SIGINT);
    return;
}

// borrowed from luasocket (socket.gettime)
double it_gets_time_process() {
    struct timeval v;
    gettimeofday(&v, (struct timezone *) NULL);
    /* Unix Epoch time (time since January 1, 1970 (UTC)) */
    return v.tv_sec + v.tv_usec/1.0e6;
}
