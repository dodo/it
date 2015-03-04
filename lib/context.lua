local Process = dofile(_it.libdir .. 'process.lua')
local EventEmitter = require 'events'


process = Process:new()
process.context = EventEmitter:new()
package.loaded['it.process'] = process

process.context.run    = process.context:bind('emit', '__run')
process.context.import = process.context:bind('once', '__run')

-- backwards compatibility
process:on('exit', process.context:bind('emit', 'exit'))

require('util.doc').rm()
-- print(require('util').dump(_G))
