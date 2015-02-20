local io = require 'io'
local ffi = require 'ffi'
local EventEmitter = require 'events'
local Metatype = require 'metatype'


local Process = EventEmitter:fork()
Process._type = Metatype:typedef('struct _$', 'it_processes')

function Process:init()
    self.prototype.init(self)
    _it.boots(self)
    self.reload= self:bind('emit', 'reload')
    self.sleep = self:bind('sleep')
    self.time  = self:bind('time')
    self.exit  = self:bind('exit')
    self.cwd   = self:bind('cwd')
    self.initialized = false
    self.shutdown = true
    -- reserve these as command line flags
    self.debugmode = nil
    self.debugger = nil
    self.verbose = nil
    -- reserve these for thread scopes
    self.context = nil
    -- reserve these for user callbacks
    self.main  = nil -- c event loop callback
    self.load  = nil
    self.setup = nil
    self.loop  = nil
    -- stdio
    self.stdnon = nil
    self.stdout = io.stdout
    self.stderr = io.stderr
    self.stdin = io.stdin
    --load funcinfo
    if #self.argv == 0 then
        require 'util.funcinfo'
        require('util.doc')
            .info(self.cwd,   'process.cwd',   '( [path] )')
            .info(self.sleep, 'process.sleep', '( milliseconds )')
            .info(self.exit,  'process.exit',  '( [code=0] )')
            .info(Process.init,   'process:init',   '( )')
            .info(Process.cwd,   'process:cwd',   '( [path] )')
            .info(Process.sleep, 'process:sleep', '( milliseconds )')
            .info(Process.exit,  'process:exit',  '( [code=0] )')
    end
    -- load api
    self.native = self._type:load('api', {
        time = "double it_gets_time_process()";
        exit = "void it_exits_process(it_processes* process, int exit_code)";
    }):ptr(_D._it_processes_)
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

ffi.cdef("int poll(struct pollfd *fds, unsigned long nfds, int timeout);")
function Process:sleep(milliseconds)
    ffi.C.poll(nil, 0, milliseconds)
end

function Process:time()
    return self.native.time()
end

function Process:exit(code)
    self.native:exit(code or 0)
end

function Process.debug()
    process.debugmode = true
    require('jit.v').start()
    require('jit.dump').start()
end


return Process
