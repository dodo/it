local EventEmitter = require 'events'
local bind = require('util').bind

local Process = EventEmitter:fork()

_it.loads('Process')
function Process:init()
    self.shutdown = true
    self._handle = _it.boots(self)
    -- convenience
    self.exit = self:bind('exit')
    self.cwd  = self._handle.cwd
    print(self.on)
end

function Process:exit(...)
    self._handle.exit(...)
end

-- -- -- -- -- -- -- --

process = Process:new()

if #process.argv == 0 then
    print "no repl, no script file."
    process.exit(1)
else
    dofile(process.argv[1])
    -- TODO test if something happened
    if process.shutdown then
        process.exit() -- normally
    end
end
