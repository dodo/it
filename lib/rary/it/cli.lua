local io = require 'io'
local util = require 'util'
local doc = require 'util.doc'
local ansi = require('console').color

local cli = {}


function cli.repl()
    local repl = require 'repl.console'
    local funcinfo = require 'util.funcinfo'
    -- globals
    ffi = require 'ffi'
    cdef = require 'cdef'
    dump = require('util').dump
    -- load plugins …
    repl:loadplugin 'linenoise'
    repl:loadplugin 'history'
    repl:loadplugin 'completion'
    repl:loadplugin 'pretty_print'
    -- standard methods …
    repl:loadplugin(function ()
        function override:name()
            return 'it repl'
        end

        function override:traceback(...)
            return _TRACEBACK(...)
        end

        function override:displayerror(err)
            io.stderr:write(err)
            io.stderr:write('\n')
        end

        function around:compilechunk(compile, chunk)
            chunk = chunk:gsub('^%s*=', 'return ')
            if not chunk:match('^%s*return') and not chunk:match('=') then
                chunk = "return " .. chunk
            end
            return compile(self, chunk)
        end

        function after:shutdown()
            process.exit()
        end
    end)
    -- hold list of all core modules here
    local coremodules = getmetatable(util.lazysubmodules(nil, {
        'lib', 'util', 'async', 'buffer', 'cdef', 'cface', 'cli', 'console',
        'events', 'feature', 'fs', 'inspect', 'metatype', 'prototype',
        'reflect', 'scope', 'thread', 'window'
    }))
    -- add help command function
    help = function (...)
        if #({...}) == 0 then
            print(ansi.bold..ansi.yellow.."core modules:"..ansi.reset)
            print(funcinfo.list(coremodules))
        elseif #({...}) == 1 then
            print(funcinfo.list(...))
        else
            funcinfo.print(...)
        end
    end
    doc.info(help, 'help', '( tables... )')
    -- expose pretty_print
    pprint = function (...)
        local results = {...}
        results.n = #results
        repl:displayresults(results)
    end
    doc.info(pprint, 'pprint', '( ... )')
    -- finally start it …
    process.shutdown = false
    repl:run()
end
doc.info(cli.repl, 'cli.repl', '(  )')


return cli
