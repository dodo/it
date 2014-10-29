local Prototype = {}
Prototype.prototype = Prototype
Prototype.metatable = { __index = Prototype }


function Prototype:fork(proto)
    proto = proto or {}
    proto.prototype = self
    local fork = setmetatable(proto, { __index = self })
    fork.metatable = { __index = fork }
    return fork
end

function Prototype:new(...)
    local instance = setmetatable({}, self.metatable)
    if instance.init then instance:init(...) end
    return instance
end

function Prototype:bind(name, ...)
    self[name .. "*"] = self[name .. "*"] or
        require('util.bind').call(self, self[name], ...)
    return self[name .. "*"]
end

function Prototype:isinstance(instance)
    -- FIXME make it recursive (check parent prototypes too)
    return instance and instance.prototype == self -- prototype
end

return Prototype
