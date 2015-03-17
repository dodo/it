-- place this file in ~/.zbstudio/packages


local pykernel = {
init = [[
import os
import bpy
import luajit
from time import sleep
from _thread import start_new_thread
]], api = [[
muSchro0m = os.path.dirname("%s")
]], load = [[
if muSchro0m:
    package = luajit.globals().package
    package.cpath = ('%s/?.so;' % muSchro0m) + package.cpath
api_run = luajit.require("libapi")
luajit.execute("process.native.runsinthread = true")
]], arg = [[
luajit.execute("table.insert(process.argv, '%s')")
]], start = [[
def runit():
    # initialization steps
    luajit.execute("dofile(_it.libdir .. 'arguments.lua')") # parse'em
    api_run() # boot step
    # run forest run!
    while True:
        t = api_run()
        if isinstance(t, (int, float)): sleep(t)
start_new_thread(runit, (), {})
]],
}

local blender
local muSchro0m

local interpreter = {
    name = "blend it",
    version = "alpha",
    description = "lua in blender",
    author = "▟ ▖▟ ▖",
    api = {"baselib", "it"},
    frun = function(self,wfilename,rundebug)
        blender = blender or ide.config.path.blender -- check if the path is configured
        if not blender then
            local default = ''
            local path = default
                ..(os.getenv('PATH') or '')..':'
                ..(GetPathWithSep(self:fworkdir(wfilename)))..':'
                ..(os.getenv('HOME') and GetPathWithSep(os.getenv('HOME'))..'bin' or '')
            local paths = {}
            for p in path:gmatch("[^:]+") do
                blender = blender or GetFullPathIfExists(p, 'blender')
                table.insert(paths, p)
            end
            if not blender then
                DisplayOutput("Can't find blender executable in any of the following folders: "
                ..table.concat(paths, ", ").."\n")
                return
            end
        end
        muSchro0m = muSchro0m or ide.config.path.it -- check if the path is configured
        if not muSchro0m then
            local default = ''
            local path = default
                ..(os.getenv('PATH') or '')..':'
                ..(GetPathWithSep(self:fworkdir(wfilename)))..':'
                ..(os.getenv('HOME') and GetPathWithSep(os.getenv('HOME'))..'bin' or '')
            local paths = {}
            for p in path:gmatch("[^:]+") do
                muSchro0m = muSchro0m or GetFullPathIfExists(p, 'it')
                table.insert(paths, p)
            end
            if muSchro0m then
--                 muSchro0m = dirname(muSchro0m)
            else
                DisplayOutput("Can't find muSchro0m it executable in any of the following folders: "
                ..table.concat(paths, ", ").."\n")
                return
            end
        end

        if rundebug then
            DebuggerAttachDefault({
                runstart = ide.config.debugger.runonstart == true,
                --basedir = blender:sub(0,-3), ???
            })
        end

        local pysrc = pykernel.init
        if muSchro0m then
            pysrc = pysrc .. pykernel.api:format(muSchro0m)
        else
            pysrc = pysrc .. pykernel.api:format('')
        end
        pysrc = pysrc .. pykernel.load
        if rundebug then
            pysrc = pysrc .. pykernel.arg:format('--mobdebug')
        end
        local params = ide.config.arg.any or ide.config.arg.it
        pysrc = pysrc .. pykernel.arg:format(wx.wxFileName(wfilename):GetFullName())
        if type(params) == 'string' then
            pysrc = pysrc .. pykernel.arg:format(params)
        elseif type(params) == 'table' then
            for _i, param in ipairs(params) do
                pysrc = pysrc .. pykernel.arg:format(param)
            end
        end
        pysrc = pysrc .. pykernel.start

        local fpyname = os.tmpname()
        do local fpy = io.open(fpyname, 'w')
            fpy:write(pysrc)
            fpy:close()
        end

        local cmd = ('"%s" --python "%s"'):format(blender, fpyname)
        -- CommandLineRun(cmd,wdir,tooutput,nohide,stringcallback,uid,endcallback)
        return CommandLineRun(cmd,self:fprojdir(wfilename),true,true, nil, nil,
        function --[[onend]]()
            os.remove(fpyname)
        end)
    end,
    hasdebugger = true,
    fattachdebug = function(self) DebuggerAttachDefault() end,
    scratchextloop = true,
    takeparameters = true,
}

return {
    name = interpreter.name,
    description =interpreter.name.." "..interpreter.version,
    author = interpreter.author,
    version = interpreter.version,

    onRegister = function(self)
        ide:AddInterpreter(interpreter.name, interpreter)
    end,

    onUnRegister = function(self)
        ide:RemoveInterpreter(interpreter.name)
    end,

    hasdebugger = interpreter.hasdebugger,
    fattachdebug = function(self) DebuggerAttachDefault() end,
    scratchextloop = interpreter.scratchextloop,
--     unhideanywindow = interpreter.unhideanywindow,
    takeparameters = interpreter.takeparameters,
}
