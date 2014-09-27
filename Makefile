
it: it.c
	gcc -o $@ $^ \
		$(shell pkg-config --cflags --libs libuv) \
		$(shell pkg-config --cflags --libs luajit)
