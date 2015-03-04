
IT_DIR = ../..

IT_SRC_API = src/api.c \
	src/audio.c

IT_DEPENDS = \
	$(shell pkg-config --cflags luajit) \
	$(shell pkg-config --cflags openal)

IT_LINKS = \
	-L$(IT_DIR) -lapi \
	$(shell pkg-config --libs luajit) \
	$(shell pkg-config --libs openal)

IT_FLAGS = \
	-D PKG_OPENAL_VERSION='"$(shell pkg-config --modversion openal)"'

IT_INCLUDES = -I./include -I$(IT_DIR)/include
IT_WARNS = -Wall

CC = gcc

# DEBUG = ""
# DEBUG = -g -O0
DEBUG = -O2


all: libaudio.so ccflags

ccflags:
	echo -n ' -I./plugin/audio/include $(IT_DEPENDS)' > ccflags

libaudio.so: $(IT_SRC_API)
	$(CC) $(IT_WARNS) -shared -o $@ -fPIC $^ \
		$(IT_INCLUDES) $(DEBUG) $(IT_DEPENDS) $(IT_LINKS) $(IT_FLAGS)

clean:
	rm -f ccflags libaudio.so

.PHONY: all
