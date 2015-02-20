local _ffi = require 'util._ffi'
local util = require 'util'
local cdef = require 'cdef'
local cface = require 'cface'
local Thread = require 'thread'
local Metatype = require 'metatype'
local doc = require 'util.doc'

cdef({
    structs   = 'SDL_*',
    constants = 'SDL_*',
--     typedefs  = 'SDL_*',
    functions = 'SDL_*',
    verbose   = process.verbose,
})

local Surface = {}
Surface.type = Metatype:use('SDL2', 'SDL_', 'Surface', 'FreeSurface')


local Window = require(process.context and 'events' or 'prototype'):fork()
Window.type = Metatype:struct("it_windows", cdef)
Window.Surface = Surface

Window.type:load('libapi.so', {
    ref = 'it_refs',
    unref = 'it_unrefs',
    init = 'it_inits_window',
    create = 'it_creates_window',
    surface_from = 'it_surfaces_from_window',
    surface = 'it_surfaces_window',
    screen = 'it_screens_window',
    blit = 'it_blits_window',
    update = 'it_updates_window',
    lock = 'it_locks_window_surface',
    unlock = 'it_unlocks_window_surface',
    push = 'it_pushes_event_window',
    close = 'it_closes_window',
    __gc = 'it_frees_window',
}, cdef)


function Window:init(pointer)
    if self.prototype.init then self.prototype.init(self) end
    if pointer then
        self.native = self.type:ptr(pointer)
        self.raw = self.native.window
        self.thread = process.context.thread
        self.thread = (pointer == _D._it_windows_) and
                process.context.thread or Thread:new(self.native.thread)
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
        window:on('sdl event', function (event)
            -- TODO make sdl event moar prettier here
            window:emit('event', event)
        end)
    end)
end
doc.info(Window.init, 'window:init', '( [pointer] )')

function Window:open(title, width, height, x, y)
    self.open = nil
    self.native:create(title,
        cface.optint(x), cface.optint(y),
        width or 200, height or 200)
    self.height = tonumber(self.native.height)
    self.width = tonumber(self.native.width)
    self.raw = self.native.window
    self.thread:start()
    return self
end
doc.info(Window.open,
        'window:open',
        '( title, width=200, height=200[, x[, y]] )')

function Window:write_to_png(filename, surface)
    -- init cairo
    local screen = surface or self.native:screen()
    self.native:lock(screen)
    require('lib.cairo').surface_from(
        screen.pixels, 'ARGB32',
        self.width, self.height, self.width * 4
    ).object:write_to_png(filename)
    self.native:unlock(screen)
    return self
end
doc.info(Window.write_to_png,
        'window:write_to_png',
        '( filename[, surface=window.native:screen()] )')

function Window:render(userdata)
    -- userdata should be in native endian
    self.native:blit(self.native:surface_from(userdata))
    return self
end
doc.info(Window.render, 'window:render', '( userdata )')

function Window:surface(draw)
    if not draw then return end
    if not self._surface then
        self._surface = {}
        self._surface.sdl = self.native:surface(true)
        if self._surface.sdl == nil then self._surface = nil return end
        self._surface.cairo = require('lib.cairo').surface_from(
            self._surface.sdl.pixels,'ARGB32',
            self.width, self.height, self.width * 4
        )
        if self._surface.cairo == nil then self._surface = nil return end
    end
    if draw(self._surface.cairo) ~= false then
        self.native:blit(self._surface.sdl)
    end
    return self
end
doc.info(Window.surface, 'window:surface', '( draw_function )')

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
    return self
end
doc.info(Window.pixels,
        'window:pixels',
        '( draw_function[, surface=window.native:screen()] )')

local SDLEVENTTYPES = cdef({find=true, unions='SDL_Event'})().extent
function Window:push(name, data)
    local event_type = SDLEVENTTYPES:match('([%w_]+)%s+' .. name .. ';')
    if not event_type then error("event type not found for name " .. name) end
    local extent = cdef({find=true, structs=event_type})().extent
    local event_data = {}
    for _, tname in extent:gmatch('([%w_]+)%s+([%w_]+);') do
        if tname == 'timestamp' then
            table.insert(event_data, 0)
        else
            if not data[tname] then
                error(tname .. " is missing from provided data!")
            end
            if tname == 'type' then
                table.insert(event_data, _ffi.convert_enum('event',
                    data[tname], 'SDL_EventType', 'SDL_'))
            else
                table.insert(event_data, data[tname])
            end
        end
    end
    local event = ffi.new(event_type, event_data)
    self.native:push(ffi.new('SDL_Event', {event.type, event}))
    return self
end
doc.info(Window.push, 'window:push', '( event_name, event_data )')

function Window:close()
    self.native:close()
end
doc.info(Window.close, 'window:close', '(  )')


return Window
