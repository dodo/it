local io = require 'io'
local fs = require 'fs'
local ffi = require 'ffi'
local util = require 'util'
local EventEmitter = require 'events'
local Metatype = require 'metatype'
local haz = require('util.table').index


local Process = EventEmitter:fork()
Process._type = Metatype:typedef('struct _$', 'it_processes')

function Process:init()
    self.prototype.init(self)
    _it.boots(self)
    self.exit = self:bind('exit')
    self.shutdown = true
    -- stdio
    self.stdnon = nil
    self.stdout = io.stdout
    self.stderr = io.stderr
    self.stdin = io.stdin
end

function Process:cwd()
    ffi.cdef("char *getcwd(char *buf, size_t size);")
    return ffi.string(ffi.C.getcwd(nil, 0)) -- thanks to gnu c
end

function Process:exit(code)
    self._type:load(_it.libdir .. "/api.so", {
    exit = "void it_exits_process(it_processes* process, int exit_code)";
    }):ptr(_D.process):exit(code or 0)
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
    versions.cairo = require('cairo').version()
    for lib,version in pairs(versions) do
        if lib == 'lua' then
            version = version .. " (running with " .. _VERSION .. ")"
        end
        print(" • " .. version)
    end
    print(require('util.table').format("running on {os} {arch}",require('jit')))
    return process.exit()
end

if haz(process.argv, "--debug") then
    local color = require('console').color
    print(color.bold .. "[debug mode]" .. color.reset)
    require('encoder').debug('warning') -- at least
    require('jit.v').start() -- TODO start in threads as well
--     require('jit.dump').start() -- TODO start in threads as well
end


if #process.argv == 0 then
    require('cli').repl()
else
    if not fs.exists(process.argv[1]) then
        print "script file does not exist."
        return process.exit(1)
    end
    util.pcall(dofile, process.argv[1])
    -- TODO test if something happened
    if process.shutdown then
        process.exit() -- normally
    end
    process.shutdown = false
end
