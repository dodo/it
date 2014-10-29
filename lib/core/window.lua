local ffi = require 'ffi'
local util = require 'util'
local cface = require 'cface'
local Thread = require 'thread'
local EventEmitter = require 'events'
local Metatype = require 'metatype'

cface(_it.libdir .. "sdlsurface.h")
cface.typedef('struct _$', 'SDL_Window')
cface.typedef('struct _$', 'SDL_Renderer')



local Window = EventEmitter:fork()
Window.type = Metatype:struct("it_windows", {
    "it_threads *thread";
    "SDL_Window *window";
    "SDL_Renderer *renderer";
    "int width";
    "int height";
})

Window.type:load(_it.libdir .. "/api.so", {
    init = [[void it_inits_window(it_windows* win, it_threads* thread)]];
    create = [[void it_creates_window(it_windows* win, const char* title,
                                      const int* x, const int* y,
                                      int width, int height)]];
    surface_from = [[SDL_Surface* it_surfaces_from_window(it_windows* win,
                                      void* data)]];
    surface = [[SDL_Surface* it_surfaces_window(it_windows* win)]];
    blit = [[void it_blits_window(it_windows* win, SDL_Surface* surface)]];
    __gc = [[void it_frees_window(it_windows* win)]];
})


function Window:init(pointer)
    self.prototype.init(self)
    if pointer then
        self._handle = self.type:ptr(pointer)
        self.thread = thread -- reuse context global
        self.height = tonumber(self._handle.height)
        self.width = tonumber(self._handle.width)
        self.open = nil
        return
    end
    self.thread = Thread:new()
    self.scope = self.thread.scope
    self._handle = self.type:create(nil, self.thread.reference)
    self.scope:define('window', self._handle, function ()
        window = require('window'):new(window)
    end)
end

function Window:open(title, width, height, x, y)
    self.open = nil
    self._handle:create(title,
        cface.optint(x), cface.optint(y),
        width or 200, height or 200)
    self.height = tonumber(self._handle.height)
    self.width = tonumber(self._handle.width)
    self.thread:start()
end

function Window:render(userdata)
    -- userdata should be in native endian
    self._handle:blit(self._handle:surface_from(userdata))
end

function Window:surface(draw)
    if not draw then return end
    local cairo = require 'cairo'
    if not self._surface then
        self._surface = cairo.surface('ARGB32', self.width, self.height)
        if self._surface == nil then return end
    end
    draw(self._surface)
    self:render(cairo.get_data(self._surface))
end

function Window:close()
    -- TODO
end


return Window
