local Prototype = require 'prototype'

local Scope = Prototype:fork()

_it.loads('Context')
function Scope:init()
    self.state = _it.forks()
end

function Scope:import(method)
    return self.state:import(method)
end

function Scope:define(name, userdata, import)
    self.state:define(name, userdata)
    if import then
        self:import(import)
    end
end

function Scope:call()
    return self.state:call()
end

return Scope

