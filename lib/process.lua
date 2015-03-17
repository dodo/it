local io = require 'io'
local ffi = require 'ffi'
local EventEmitter = require 'events'
local Metatype = require 'metatype'


local Process = EventEmitter:fork()
Process._type = Metatype:struct('it_processes', {
    "int refc";
    "int argc";
    "char **argv";
    "bool runsinthread";
    "bool islibrary";
    "int exit_code";
    "void /*uv_loop_t*/ *loop";
--     … the rest is not important for lua
})

function Process:__new()
    self.prototype.__new(self)
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
    self.script = nil
    self.repl = nil
    -- reserve these for thread scopes
    self.context = nil
    -- reserve these for user callbacks
    self.boot  = nil -- c init event loop callback
    self.main  = nil -- c event loop callback
    self.load  = nil
    self.setup = nil
    self.loop  = nil
    -- stdio
    self.stdnon = nil
    self.stdout = io.stdout
    self.stderr = io.stderr
    self.stdin = io.stdin
    -- load funcinfo
    if #self.argv == 0 then
        require('util.doc')
            .info(self.cwd,   'process.cwd',   '( [path] )')
            .info(self.sleep, 'process.sleep', '( milliseconds )')
            .info(self.time,  'process.time', '(  )')
            .info(self.exit,  'process.exit',  '( [code=0] )')
            .info(Process.__new, 'Process:new()', '(  )')
            .info(Process.sleep, 'process:sleep', '( milliseconds )')
            .info(Process.time,  'process:time',  '(  )')
            .info(Process.exit,  'process:exit',  '( [code=0] )')
            .info(Process.cwd,   'process:cwd',   '( [path] )')
    end
    -- load api
    self.native = self._type:load(_it.api('api'), {
        time = "double it_gets_time_process()";
        exit = "void it_exits_process(it_processes* process, int exit_code)";
        __gc = "void it_frees_process(it_processes* process)";
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
    -- FIXME blocks all other fds
    ffi.C.poll(nil, 0, milliseconds)
end

function Process:time()
    return self.native.time()
end

function Process:exit(code)
    code = code or 0
    self.native:exit(code)
    return string.format('process.exit(%d)', code)
end

function Process.debug(mode)
    if mode == 'remote' then
        if not process.debugger then
            process:on('exit', require('mobdebug').done)
        end
        process.debugger = true
        require('mobdebug').scratch = process.reload
        -- turn jit off based on Mike Pall's comment in this discussion:
        -- http://www.freelists.org/post/luajit/Debug-hooks-and-JIT,2
        -- "You need to turn it off at the start if you plan to receive
        -- reliable hook calls at any later point in time."
        jit.off()
    else
        process.debugmode = true
        require('jit.v').start()
        require('jit.dump').start()
    end
end


return Process
