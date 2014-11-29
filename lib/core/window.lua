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
    "int refc";
    "it_threads *thread";
    "SDL_Window *window";
    "SDL_Renderer *renderer";
    "int width";
    "int height";
})

Window.type:load('libapi.so', {
    ref = [[int it_refs(it_windows* ref)]];
    unref = [[int it_unrefs(it_windows* ref)]];
    init = [[void it_inits_window(it_windows* win, it_threads* thread)]];
    create = [[void it_creates_window(it_windows* win, const char* title,
                                      const int* x, const int* y,
                                      int width, int height)]];
    surface_from = [[SDL_Surface* it_surfaces_from_window(it_windows* win,
                                      void* data)]];
    surface = [[SDL_Surface* it_surfaces_window(it_windows* win, bool no_rle)]];
    screen = [[SDL_Surface* it_screens_window(it_windows* win)]];
    blit = [[void it_blits_window(it_windows* win, SDL_Surface* surface)]];
    update = [[void it_updates_window(it_windows* win)]];
    lock = [[void it_locks_window_surface(it_windows* win, SDL_Surface* surface)]];
    unlock = [[void it_unlocks_window_surface(it_windows* win, SDL_Surface* surface)]];
    close = [[void it_closes_window(it_windows* win)]];
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

function Window:write_to_png(filename, surface)
    -- init cairo
    local screen = surface or self.native:screen()
    self.native:lock(screen)
    require('cairo').surface_from(
        screen.pixels, 'ARGB32',
        self.width, self.height, self.width * 4
    ).object:write_to_png(filename)
    self.native:unlock(screen)
end

function Window:render(userdata)
    -- userdata should be in native endian
    self.native:blit(self.native:surface_from(userdata))
end

function Window:surface(draw)
    if not draw then return end
    if not self._surface then
        self._surface = {}
        self._surface.sdl = self.native:surface(true)
        if self._surface.sdl == nil then self._surface = nil return end
        self._surface.cairo = require('cairo').surface_from(
            self._surface.sdl.pixels,'ARGB32',
            self.width, self.height, self.width * 4
        )
        if self._surface.cairo == nil then self._surface = nil return end
    end
    if draw(self._surface.cairo) ~= false then
        self.native:blit(self._surface.sdl)
    end
end

function Window:pixels(draw, surface)
    if not draw then return end
    local screen = surface or self.native:screen()
    if screen == nil then return end
    self.native:lock(screen)
    local can_blit = draw(screen.pixels)
    self.native:unlock(screen)
    if can_blit ~= false then
        if surface then
            self.native:blit(screen)
        else
            self.native:update()
        end
    end
end

function Window:close()
    self.native:close()
end


return Window
