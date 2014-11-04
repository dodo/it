local io = require 'io'
local ffi = require 'ffi'
local EventEmitter = require 'events'
local Metatype = require 'metatype'


local Process = EventEmitter:fork()
Process._type = Metatype:typedef('struct _$', 'it_processes')

function Process:init()
    self.prototype.init(self)
    _it.boots(self)
    self.exit = self:bind('exit')
    self.cwd  = self:bind('cwd')
    self.shutdown = true
    -- stdio
    self.stdnon = nil
    self.stdout = io.stdout
    self.stderr = io.stderr
    self.stdin = io.stdin
end

function Process:cwd(path)
    ffi.cdef("char *getcwd(char *buf, size_t size);")
    local cwd = ffi.string(ffi.C.getcwd(nil, 0)) -- thanks to gnu c
    if path then
        ffi.cdef("int chdir(const char *path);")
        if ffi.C.chdir(path) ~= 0 then
            error("failed to change cwd to " .. path)
        end
    end
    return cwd
end

function Process:exit(code)
    self._type:load('api', {
    exit = "void it_exits_process(it_processes* process, int exit_code)";
    }):ptr(_D.process):exit(code or 0)
end


return Process
