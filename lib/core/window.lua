local ffi = require 'ffi'
local util = require 'util'
local cface = require 'cface'
local Thread = require 'thread'
local Metatype = require 'metatype'

cface(_it.libdir .. "sdlsurface.h")
cface.typedef('struct _$', 'SDL_Window')
cface.typedef('struct _$', 'SDL_Renderer')

local Surface = {}
Surface.type = Metatype:use('SDL2', 'SDL_', 'Surface', 'FreeSurface')


local Window = require(context and 'events' or 'prototype'):fork()
Window.type = Metatype:struct("it_windows", {
    "it_threads *thread";
    "SDL_Window *window";
    "SDL_Renderer *renderer";
    "int width";
    "int height";
})

Window.type:load('libapi.so', {
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
    if self.prototype.init then self.prototype.init(self) end
    if pointer then
        self.native = self.type:ptr(pointer)
        self.raw = self.native.window
        self.thread = context.thread
        self.thread = (pointer == _D._it_windows_) and
                context.thread or Thread:new(self.native.thread)
        self.height = tonumber(self.native.height)
        self.width = tonumber(self.native.width)
        self.open = nil
        return
    end
    self.thread = Thread:new()
    self.scope = self.thread.scope
    self.native = self.type:create(nil, self.thread.reference)
    self.scope:define('_it_windows_', self.native, function ()
        window = require('window'):new(_D._it_windows_)
    end)
end

function Window:open(title, width, height, x, y)
    self.open = nil
    self.native:create(title,
        cface.optint(x), cface.optint(y),
        width or 200, height or 200)
    self.height = tonumber(self.native.height)
    self.width = tonumber(self.native.width)
    self.raw = self.native.window
    self.thread:start()
end

function Window:render(userdata)
    -- userdata should be in native endian
    self.native:blit(self.native:surface_from(userdata))
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
