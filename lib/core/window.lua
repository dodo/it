local util = require 'util'
local Thread = require 'thread'
local EventEmitter = require 'events'


local Window = EventEmitter:fork()


_it.loads('Window')
function Window:init(pointer)
    self.prototype.init(self)
    self._pointer = pointer
    self._handle = _it.windows(pointer)
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
    self._handle:create(title, x, y, width or 200, height or 200)
    self.thread:start()
end

function Window:surface(width, height, draw)
    self:render(width, height, function (data)
        local surface = util.cairo_surface(data, 'ARGB', width, height)
        draw(surface.context, surface.object)
    end)
end

function Window:close()
    self._handle:close()
end


return Window
