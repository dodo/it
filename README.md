muSchro0m it
============


C Deps: (apt-get install *-dev)
    * libuv
    * luajit
    * libschrödinger
    * liboggz
    * liborc
    * libsdl2
    * libcairo
    * libopenal

Lua Deps: (luarocks install *)
    * linenoise
    * lua-term
    * luarepl

```bash
cd it
docker build -t devit .
docker run -v `pwd`:/home/dev -u dev -it devit bash
make standalone
```
