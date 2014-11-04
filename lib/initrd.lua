local io = require 'io'
local fs = require 'fs'
local util = require 'util'
local haz = require('util.table').index

local Process = dofile(_it.libdir .. 'process.lua')

function Process:usage()
    return [[
Usage: it [options] scripts.lua [arguments]

Options:
  -v --version      print versions
  -h --help         magic flag
]] end

process = Process:new()

-- -- -- -- -- -- -- --

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
    local loaded, encoder = pcall(require, 'encoder')
    if loaded then encoder.debug('warning') end
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
