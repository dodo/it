muSchro0m it
============


C Deps: (apt-get install *-dev)
 * clang (no dev needed)
 * libclang
 * libuv
 * luajit
 * liboggz
 * liborc
 * libsdl2
 * libcairo
 - *optional*:
 * libopenal
 * libschrödinger (patched)

Lua Deps: (luarocks install *)
 * linenoise
 * lua-term
 * luarepl
 - *optional*:
 * [mobdebug](https://github.com/pkulchenko/MobDebug)
 * [torch7](/http://torch.ch)


```bash
git clone --recursive https://github.com/dodo/it
cd it
docker build -t devit .
docker run -v `pwd`:/home/dev -u dev -it devit bash
make standalone
# or with openal
make audio standalone
```
