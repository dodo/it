local Process = dofile(_it.libdir .. 'process.lua')
local EventEmitter = require 'events'


process = Process:new()
context = EventEmitter:new()

context.run    = context:bind('emit', '__run')
context.import = context:bind('on',   '__run')

-- print(require('util').dump(_G))
