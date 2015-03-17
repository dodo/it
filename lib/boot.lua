local io = require 'io'
local fs = require 'fs'
local util = require 'util'
local doc = require 'util.doc'


if process.script then
    if not fs.exists(process.script) then
        print(string.format("script file '%s' does not exist.",
                            process.script))
        return process.exit(1)
    end
    if not process.repl then doc.rm() end
    local result
    if process.debugger then
        io.stdout:setvbuf("no") -- disable print buffering
        -- inject debugger loading code into script file …
        -- … to set entry point to the script
        -- but postbone debugging until running the actual loop
        local chunk = fs.read(process.script) .. "\n"
            .. " if process.debugger and not process.initialized then"
            .. "     require('mobdebug').start() require('mobdebug').off()"
            .. " end"
        local code = util.pcall(loadstring, chunk, process.script)
        result = util.pcall(code)
    else
        result = util.pcall(dofile, process.script)
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
        if not process.repl then
            process.exit() -- normally
            return result
        end
    end
    process.shutdown = false
    if type(process.loop) == 'function' and process.debugger then
        -- auto enable debugger just around the loop
        return function (...)
            require('mobdebug').on()
            local res = process.loop(...)
            require('mobdebug').off()
            return res
        end
    end
end

if process.repl then
    doc.init()
    require('cli').repl()
    return
end

return process.loop
