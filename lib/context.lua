local EventEmitter = require 'events'

context = EventEmitter:new()

context.run    = context:bind('emit', 'run')
context.import = context:bind('on',   'run')

process = EventEmitter:new()
_it.stdios(process)
