local Process = dofile(_it.libdir .. 'process.lua')
local io = require 'io'
local fs = require 'fs'
local util = require 'util'
local haz = require('util.table').index
local doc = require 'util.doc'


function Process:usage()
    return [[
Usage: it [options] scripts.lua [arguments]

Options:
  -v --version      print versions
  -h --help         magic flag
]] end

process = Process:new()
doc.info(Process.usage, 'process.usage', '( )')

-- -- -- -- -- -- -- --

if haz(process.argv, "-h") or haz(process.argv, "--help") then
    print(process.usage())
    return process.exit()
end


if haz(process.argv, "-v") or haz(process.argv, "--version") then
    local versions = _it.versions()
    print(versions.it)
    versions.it = nil
    versions.cairo = require('lib.cairo').version()
    versions.pixman = require('lib.pixman').version()
    for lib,version in pairs(versions) do
        if lib == 'lua' then
            version = version .. " (running with " .. _VERSION .. ")"
        end
        print(" • " .. version)
    end
    for _,name in pairs({dofile(_it.libdir .. 'plugins.lua')}) do
        if name and _it.plugin[name] then
            local versions = _it.versions(_it.plugin[name].apifile)
            print(string.format("[%s]", versions.name))
            versions.name = nil
            for lib,version in pairs(versions) do
                print(" • " .. version)
            end
        end
    end
    print(require('util.table').format("running on {os} {arch}",require('jit')))
    return process.exit()
end

if haz(process.argv, "--debug") then
    local color = require('console').color
    print(color.bold .. "[debug mode]" .. color.reset)
    table.remove(process.argv, haz(process.argv, "--debug"))
    local loaded, encoder = pcall(require, 'encoder')
    if loaded then encoder.debug('debug') end
    process.debug()
end


return function () -- called when finally initialized
    if #process.argv == 0 then
        doc.init()
        require('cli').repl()
    else
        if not fs.exists(process.argv[1]) then
            print "script file does not exist."
            return process.exit(1)
        end
        doc.rm()
        local result = util.pcall(dofile, process.argv[1])
        -- TODO test if something happened
        if type(result) ~= 'function' and process.shutdown then
            process.exit() -- normally
        end
        process.shutdown = false
        return result
    end
end
