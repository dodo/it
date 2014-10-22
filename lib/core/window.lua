local util = require 'util'
local Thread = require 'thread'
local EventEmitter = require 'events'


local Window = EventEmitter:fork()


_it.loads('Window')
function Window:init(pointer)
    self.prototype.init(self)
    self._pointer = pointer
    self._handle = _it.windows(self, pointer)
    if pointer then
        self.open = nil
        return
    end
    self.thread = Thread:new()
    self.scope = self.thread.scope
    self._handle:init(self.thread.reference)
    -- process 'userdata' events to 'data' events
    self.scope:import(function ()
        -- window handle gets injected right before
        window = require('window'):new(window)
    end)
end

function Window:open(title, width, height, x, y)
    self.open = nil
    self.width = width or 200
    self.height = height or 200
    self._handle:create(title, x, y, self.width, self.height)
    self.thread:start()
end

function Window:render(width, height, userdata, stride, big_endian)
    -- userdata should be in native endian
    if type(userdata) == 'userdata' then
        self._handle.render(
            self._pointer or self._handle,
            width, height, userdata, stride
        )
    elseif type(userdata) == 'function' then
        local callback = userdata
        self._handle.render(
            self._pointer or self._handle,
            width, height, callback
        )
    end
end

function Window:surface(draw)
    self:render(self.width, self.height, function (data)
        local surface = util.cairo_surface(data, 'ARGB', self.width, self.height)
        draw(surface.context, surface.object)
    end)
end

function Window:close()
    self._handle:__gc()
end


return Window
