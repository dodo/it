
it: it.c
	gcc -o $@ $^ \
		-I/usr/include -lev \
		$(shell pkg-config --cflags --libs luajit)
