local doc = require 'util.doc'
local debug = require 'debug'


local Prototype = {}
Prototype.__index = Prototype
Prototype.prototype = Prototype


function Prototype:fork(proto)
    local fork = proto or {}
    local metatable = self
    local mt = debug.getmetatable(fork)
    if mt and mt.__metatable then
        -- prevent changing a protected metatable
        fork = {}
        metatable = {
            __index = self,
            __metatable = mt.__metatable,
        }
        -- dont break self.prototype lookup behavior
        setmetatable(metatable, metatable)
    end
    fork.__index = fork
    fork.prototype = metatable
    if type(fork) == 'userdata' then -- hopefully it's not a lightuserdata
        debug.setmetatable(fork, metatable)
    else
              setmetatable(fork, metatable)
    end
    return fork
end
doc.info(Prototype.fork, 'Prototype:fork', '( proto={} )')

function Prototype:new(...)
    local instance = setmetatable({}, self)
    if instance.__new then instance:__new(...) end
    return instance
end
doc.info(Prototype.new, 'proto:new', '( [...] )')

function Prototype:cast(pointer, ...)
    local instance = setmetatable({}, self)
    if pointer then
        if instance.__cast then instance:__cast(pointer, ...)
        else error("cannot cast pointer! __cast method is missing!")
        end
    else -- casting nil is as good as creating a new instance
        if instance.__new then instance:__new(...) end
    end
    return instance
end
doc.info(Prototype.cast, 'proto:cast', '( pointer[, ...] )')

function Prototype:bind(name, ...)
    self[name .. "*"] = self[name .. "*"] or
        require('util.bind').call(self, self[name], ...)
    return self[name .. "*"]
end
doc.info(Prototype.bind, 'instance:bind', '( name[, ...] )')

function Prototype:isinstance(instance)
    -- FIXME make it recursive (check parent prototypes too)
    return instance and (instance.prototype == self or getmetatable(instance) == self) -- prototype
end
doc.todo(Prototype.isinstance, 'proto:isinstance', '( instance )')

return Prototype
