local io = require 'io'
local Metatype = require 'metatype'
local EventEmitter = require 'events'


process = EventEmitter:new()
process._type = Metatype:typedef('struct _$', 'it_processes')
-- stdio
process.stdnon = nil
process.stdout = io.stdout
process.stderr = io.stderr
process.stdin = io.stdin

function process.exit(code)
    process._type:load(_it.libdir .. "/api.so", {
    exit = "void it_exits_process(it_processes* process, int exit_code)";
    }):ptr(_D.process):exit(code or 0)
end

-- -- -- -- -- -- -- --

context = EventEmitter:new()

context.run    = context:bind('emit', '__run')
context.import = context:bind('on',   '__run')

-- print(require('util').dump(_G))
