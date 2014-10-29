local io = require 'io'

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
    -- finally start it …
    process.shutdown = false
    repl:run()
end


return cli
