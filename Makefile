
it: it.c src/it.c src/luaI.c src/lua/it.c src/lua/ctx.c src/lua/enc.c
	gcc -Wall -o $@ $^ -I./include \
		-lpthread \
		$(shell pkg-config --cflags --libs libuv) \
		$(shell pkg-config --cflags --libs luajit) \
		$(shell pkg-config --cflags --libs schroedinger-1.0)
