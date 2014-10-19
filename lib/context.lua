local EventEmitter = require 'events'

--  needed to build stacktrace
_it.getlines = function (...)
    return require('fs').line(...)
end

context = EventEmitter:new()

context.run    = context:bind('emit', 'run')
context.import = context:bind('on',   'run')

process = EventEmitter:new()
_it.stdios(process)
