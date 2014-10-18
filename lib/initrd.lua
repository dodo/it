local EventEmitter = require 'events'
local util = require 'util'

local Process = EventEmitter:fork()

_it.loads('Process')
function Process:init()
    self.prototype.init(self)
    _it.stdios(self)
    self.shutdown = true
    self._handle = _it.boots(self)
    -- convenience
    self.exit = self:bind('exit')
    self.cwd  = self._handle.cwd
end

function Process:exit(...)
    self._handle.exit(...)
end

-- -- -- -- -- -- -- --

process = Process:new()

if util.table_index(process.argv, "--version") > 0 then
    local versions = _it.versions()
    print(versions.it)
    versions.it = nil
    for lib,version in pairs(versions) do
        if lib == 'lua' then
            version = version .. " (running with " .. _VERSION .. ")"
        end
        print(" • " .. version)
    end
    return process.exit()
end

if #process.argv == 0 then
    print "no repl, no script file."
    process.exit(1)
else
    dofile(process.argv[1])
    -- TODO test if something happened
    if process.shutdown then
        process.exit() -- normally
    end
    process.shutdown = false
end
