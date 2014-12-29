local io = require 'io'
local doc = require 'util.doc'

local cli = {}


function cli.repl()
    local repl = require 'repl.console'
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
            return compile(self, chunk:gsub('^%s*=', 'return '))
        end

        function after:shutdown()
            process.exit()
        end
    end)
    -- add help command function
    help = function (...)
        if #({...}) == 0 then
            print "hello world!"
        elseif #({...}) == 1 then
            print(require('util.funcinfo').list(...))
        else
            require('util.funcinfo').print(...)
        end
    end
    -- globals
    ffi = require 'ffi'
    -- finally start it …
    process.shutdown = false
    repl:run()
end
doc.info(cli.repl, 'cli.repl', '(  )')


return cli
