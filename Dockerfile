FROM dock0/arch
MAINTAINER ▟ ▖▟ ▖

RUN useradd -m -g users -G wheel -s /bin/bash dev

RUN pacman -Sy --noconfirm
RUN pacman -S  --noconfirm \
    tar pkg-config make gcc \
    luajit libuv cairo sdl2 \
    luarocks5.1 libnoise

RUN luarocks-5.1 install luarepl \
 && luarocks-5.1 install linenoise

USER dev
ENV HOME /home/dev
WORKDIR  /home/dev