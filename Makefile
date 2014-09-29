
it: it.c src/it.c src/luaI.c src/lua/it.c src/lua/ctx.c
	gcc -Wall -o $@ $^ -I./include \
		$(shell pkg-config --cflags --libs libuv) \
		$(shell pkg-config --cflags --libs luajit)
