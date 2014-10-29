local io = require 'io'

local cli = {}


function cli.repl()
    local repl = require 'repl.console'
    repl:loadplugin 'linenoise'
    repl:loadplugin 'history'
    repl:loadplugin 'completion'
--     repl:loadplugin 'autoreturn'
    repl:loadplugin 'pretty_print'

    function repl:name()
        return 'it repl'
    end

    function repl:traceback(...)
        return _TRACEBACK(...)
    end

    local compilechunk = repl.compilechunk
    function repl:compilechunk(chunk)
        return compilechunk(self, chunk:gsub('^%s*=', 'return '))
    end

    function repl:displayerror(err)
        io.stderr:write(err)
        io.stderr:write('\n')
    end

    function repl:shutdown()
        process.exit()
    end

    process.shutdown = false
    repl:run()
end


return cli
