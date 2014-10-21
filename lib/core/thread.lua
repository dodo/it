local Scope = require 'scope'
local Prototype = require 'prototype'


local Thread = Prototype:fork()


_it.loads('Thread')
function Thread:init()
    self.scope = Scope:new()
    self.reference = _it.capsules()
    self.reference:init(self.scope.state)
end

function Thread:start()
    process.shutdown = false -- prevent process from shutting down
    self.reference:create()
end

function Thread:join()
    self.reference:__gc()
end


return Thread


