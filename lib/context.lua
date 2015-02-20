local Process = dofile(_it.libdir .. 'process.lua')
local EventEmitter = require 'events'


process = Process:new()
process.context = EventEmitter:new()

process.context.run    = process.context:bind('emit', '__run')
process.context.import = process.context:bind('on',   '__run')

require('util.doc').rm()
-- print(require('util').dump(_G))
