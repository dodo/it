local Scope = require 'scope'
local Prototype = require 'prototype'


local Thread = Prototype:fork()


_it.loads('Thread')
function Thread:init(pointer)
    self.reference = _it.capsules(pointer)
    if pointer then
        self.start = nil
        return
    end
    self.scope = Scope:new()
    self.reference:init(self.scope.state)
    self.scope:import(function ()
        -- thread handle gets injected right before
        thread = require('thread'):new(thread)
    end)
end

function Thread:start()
    process.shutdown = false -- prevent process from shutting down
    self.reference:create()
end

function Thread:join()
    self.reference:__gc()
end


return Thread


