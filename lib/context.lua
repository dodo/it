context = require('events'):new()

context.run    = context:bind('emit', 'run')
context.import = context:bind('on',   'run')

process = {}
_it.stdios(process)
