local fs = require 'fs'
local EventEmitter = require 'events'
local haz = require('util').table_index

--  needed to build stacktrace
_it.getlines = fs.line

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

function Process:usage()
    return [[
Usage: it [options] scripts.lua [arguments]

Options:
  -v --version      print versions
  -h --help         magic flag
]] end

-- -- -- -- -- -- -- --

process = Process:new()

if haz(process.argv, "-h") or haz(process.argv, "--help") then
    print(process.usage())
    return process.exit()
end


if haz(process.argv, "-v") or haz(process.argv, "--version") then
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
    if not fs.exists(process.argv[1]) then
        print "script file does not exist."
        return process.exit(1)
    end
    dofile(process.argv[1])
    -- TODO test if something happened
    if process.shutdown then
        process.exit() -- normally
    end
    process.shutdown = false
end
