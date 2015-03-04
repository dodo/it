local Process = dofile(_it.libdir .. 'process.lua')
local io = require 'io'
local fs = require 'fs'
local util = require 'util'
local haz = require('util.table').index
local doc = require 'util.doc'


function Process:usage()
    local usage = [[
Usage: it [options] scripts.lua [arguments]

Options:
  -m --main <module> require module and run module.__main function
  --debug            enable debug mode (jit.v,jit.dump)
]]
    if pcall(require, 'mobdebug') then
        usage = usage .. [[
  --mobdebug         enable remote debug mod (mobdebug)
]]
    end
    usage = usage .. [[
  --verbose          increase verbosity
  -v --version       print versions
  -h --help          magic flag
]]
    return usage
end
doc.info(Process.usage, 'process.usage', '( )')

process = Process:new()
package.loaded['it.process'] = process

-- -- -- -- -- -- -- --

if haz(process.argv, "-h") or haz(process.argv, "--help") then
    print(process.usage())
    return process.exit()
end


if haz(process.argv, "-v") or haz(process.argv, "--version") then
    dofile(_it.libdir .. 'version.lua')
    return process.exit()
end

if haz(process.argv, "--verbose") then
    table.remove(process.argv, haz(process.argv, "--verbose"))
    process.verbose = true
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
    table.remove(process.argv, haz(process.argv, "--mobdebug"))
    if pcall(require, 'mobdebug') then
        local color = require('console').color
        print(color.bold .. "[remote debug mode]" .. color.reset)
        require('mobdebug').scratch = process.reload
        process.debugger = true
        -- turn jit off based on Mike Pall's comment in this discussion:
        -- http://www.freelists.org/post/luajit/Debug-hooks-and-JIT,2
        -- "You need to turn it off at the start if you plan to receive
        -- reliable hook calls at any later point in time."
        jit.off()
    end
end

if haz(process.argv, "-m") or haz(process.argv, "--main") then
    local i = haz(process.argv, "-m") or haz(process.argv, "--main")
    table.remove(process.argv, i)
    local modulename = process.argv[i]
    table.remove(process.argv, i)
    doc.rm()
    return function --[[boot]]()
        local module = util.pcall(require, modulename)
        if not module.__main then
            print(string.format("module '%s' does not have a __main function.",
                                modulename))
            return process.exit(1)
        end
        local result = util.pcall(module.__main) -- could return a loop
        process.initialized = true
        return result
    end
end


return function --[[boot]]() -- called when finally initialized
    if #process.argv == 0 then
        doc.init()
        require('cli').repl()
    else
        if not fs.exists(process.argv[1]) then
            print(string.format("script file '%s' does not exist.",
                                process.argv[1]))
            return process.exit(1)
        end
        doc.rm()
        local result
        if process.debugger then
            io.stdout:setvbuf("no") -- disable print buffering
            -- inject debugger loading code into script file …
            -- … to set entry point to the script
            -- but postbone debugging until running the actual loop
            local chunk = fs.read(process.argv[1]) .. "\n"
                .. " if process.debugger and not process.initialized then"
                .. "     require('mobdebug').start() require('mobdebug').off()"
                .. " end"
            local code = util.pcall(loadstring, chunk, process.argv[1])
            result = util.pcall(code)
        else
            result = util.pcall(dofile, process.argv[1])
        end
        -- TODO test if something happened
        if type(process.load) == 'function' then
            -- called only at the beginning of the process
            process.load() -- run this only once!
        end
        process.initialized = true
        if type(process.setup) == 'function' then
            -- called at the beginning of the session
            -- (could be called at a reload again)
            process.setup() -- run this at the beginning
            -- and run this every time the process reloads (eg when debugger execs)
            process:on('reload', function ()
                -- setup might change between reloads
                process.setup()
            end)
        end
        -- allow to set process.loop as global main loop
        process.loop = process.loop or result
        if type(process.loop) ~= 'function' and process.shutdown then
            process.exit() -- normally
            return result
        end
        process.shutdown = false
        if type(process.loop) == 'function' and process.debugger then
            -- auto enable debugger just around the loop
            return function (...)
                require('mobdebug').on()
                process.loop(...)
                require('mobdebug').off()
            end
        end
        return process.loop
    end
end
