local Scope = require 'scope'
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
    self.scope = Scope:new()
    self._handle:init(self.scope.state)
end

function Window:open(title, width, height, x, y)
    self._handle:create(title, x, y, width or 200, height or 200)
end

function Window:close()
    self._handle:close()
end


return Window
