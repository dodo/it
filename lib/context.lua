local EventEmitter = require 'events'

--  needed to build stacktrace
_it.getlines = function (...)
    return require('fs').line(...)
end

context = EventEmitter:new()

context.run    = context:bind('emit', 'run')
context.import = context:bind('on',   'run')

_it.loads('Process')
process = EventEmitter:new()
_it.stdios(process)

function process.exit(...)
     _it.boots().exit(...)
end
