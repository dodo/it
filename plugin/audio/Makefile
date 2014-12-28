
IT_DIR = ../..

# FIXME
IT_DEPENDS = \
	-L$(IT_DIR) -lapi \
	$(shell pkg-config --cflags --libs luajit) \
	$(shell pkg-config --cflags --libs openal)

IT_FLAGS = \
	-D PKG_OPENAL_VERSION='"$(shell pkg-config --modversion openal)"'

IT_INCLUDES = -I./include -I$(IT_DIR)/include
IT_WARNS = -Wall

# DEBUG = ""
# DEBUG = -g -O0
DEBUG = -O2


all: libaudio.so

libaudio.so: src/api.c \
	src/audio.c
	gcc $(IT_WARNS) -shared -o $@ -fPIC $^ \
		$(IT_INCLUDES) $(DEBUG) $(IT_DEPENDS) $(IT_FLAGS)

clean:
	rm -f libaudio.so

.PHONY: all
