#include <stdio.h>
#include <ev.h>


typedef struct {
    struct ev_loop *loop;
    ev_signal *sigint;
} it_states;


static void sigint_cb(struct ev_loop *loop, ev_signal *w, int revents) {
    ev_break(loop, EVBREAK_ALL);
}


int main(void) {
    it_states state;
    state.loop = EV_DEFAULT;

    ev_signal sigint_signal;
    state.sigint = &sigint_signal;


    ev_signal_init(state.sigint, sigint_cb, SIGINT);
    ev_signal_start(state.loop, state.sigint);

    // run forest run!
    ev_run(state.loop, 0);

    return 0;
}