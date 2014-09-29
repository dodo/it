
it: it.c
	gcc -Wall -o $@ $^ \
		$(shell pkg-config --cflags --libs libuv) \
		$(shell pkg-config --cflags --libs luajit)
