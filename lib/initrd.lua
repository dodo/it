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
    dofile(_it.libdir .. 'version.lua')
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

if haz(process.argv, "--mobdebug") then
    local color = require('console').color
    print(color.bold .. "[remote debug mode]" .. color.reset)
    table.remove(process.argv, haz(process.argv, "--mobdebug"))
    process.debugger = true
end

return function () -- called when finally initialized
    if #process.argv == 0 then
        doc.init()
        require('cli').repl()
    else
        if not fs.exists(process.argv[1]) then
            print(string.format("script file '%s' does not exist.", process.argv[1]))
            return process.exit(1)
        end
        doc.rm()
        local result
        if debugger then
            io.stdout:setvbuf("no") -- disable print buffering
            -- inject debugger loading code into script file …
            -- … to set entry point to the script
            -- but postbone debugging until running the actual loop
            -- FIXME this breaks sheebangs
            local chunk = "if process.debugger and not process.initialized then"
                .. " require('mobdebug').start() require('mobdebug').off() "
                .. " end; " .. fs.read(process.argv[1])
            local code = util.pcall(loadstring, chunk, process.argv[1])
            result = util.pcall(code)
        else
            result = util.pcall(dofile, process.argv[1])
        end
        process.initialized = true
        -- TODO test if something happened
        if type(result) ~= 'function' and process.shutdown then
            process.exit() -- normally
            return result
        end
        process.shutdown = false
        if type(result) == 'function' then
            if process.debugger then
                -- auto enable debugger just around the loop
                return function (...)
                    require('mobdebug').on()
                    result(...) -- loop
                    require('mobdebug').off()
                end
            end
        end
        return result
    end
end
