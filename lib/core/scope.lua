local Prototype = require 'prototype'

local Scope = Prototype:fork()

_it.loads('Context')
function Scope:init()
    self.state = _it.forks()
end

function Scope:import(method)
    return self.state:import(method)
end

function Scope:call()
    return self.state:call()
end

return Scope

