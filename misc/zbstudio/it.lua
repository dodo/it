-- place this file in ~/.zbstudio/packages

local muSchro0m

local interpreter = {
    name = "muSchro0m it",
    version = "alpha",
    description = "lua on muSchro0ms",
    author = "▟ ▖▟ ▖",
    api = {"baselib", "it"},
    frun = function(self,wfilename,rundebug)
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
            if not muSchro0m then
                DisplayOutput("Can't find muSchro0m it executable in any of the following folders: "
                ..table.concat(paths, ", ").."\n")
                return
            end
        end

    --    if not GetFullPathIfExists(self:fworkdir(wfilename), 'main.lua') then
    --      DisplayOutput("Can't find 'main.lua' file in the current project folder.\n")
    --      return
    --    end

        if rundebug then
            DebuggerAttachDefault({
                runstart = ide.config.debugger.runonstart == true,
                --basedir = muSchro0m:sub(0,-3), ???
            })
        end

        local params = ide.config.arg.any or ide.config.arg.it
        local cmd = ('"%s"%s "%s"%s'):format(muSchro0m,
        rundebug and ' --mobdebug' or '',
        wx.wxFileName(wfilename):GetFullName(),
        params and ' '..params or "")
        -- CommandLineRun(cmd,wdir,tooutput,nohide,stringcallback,uid,endcallback)
        return CommandLineRun(cmd,self:fprojdir(wfilename),true,true)
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
