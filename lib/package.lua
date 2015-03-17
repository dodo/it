-- preload ffi core module into cache
require 'ffi'


-- prepend to lua search paths
package.path = './?/init.lua;' .. package.path

-- add new path to api libs (core + plugins)
package.apicpath = _it.execpath .. 'lib?.so'
package.apipath = _it.libdir .. 'rary/?/init.lua'
package.apipath = _it.libdir .. 'rary/?.lua;' .. package.apipath

-- load all plugin meta information
_it.plugin = {}
for _,name in pairs({dofile(_it.libdir .. 'plugins.lua')}) do
    if name then
        local plugin = {}
        plugin.path = _it.plugindir .. name .. '/'
        plugin.libdir = plugin.path .. 'lib/'
        plugin.apifile = 'lib' .. name .. '.so'
        package.apicpath = package.apicpath .. ';'
            .. plugin.path .. 'lib?.so'
        package.apipath = package.apipath .. ';'
            .. plugin.libdir .. 'rary/?.lua;'
            .. plugin.libdir .. 'rary/?/init.lua'
        _it.plugin[name] = plugin
    end
end

function _it.api(name)
    return package.searchpath(name, package.apicpath)
end

--create api loader
local function api_loader(name)
    local path, err = package.searchpath(name, package.apipath)
    if not path then return string.format('%s\n', err or '') end
    return loadfile(path)
end

-- loader for local files (dont use cwd to expand relative paths)
local function local_loader(name)
    if not name then return end
    local i, info = 3, {what = "C"}
    if name:sub(1, 2) ~= './' then return end
    name = name:sub(3) -- cut off ./
    if not name:lower():match('%.lua$') then
        name = name .. '.lua'
    end
    -- HACK travel thtough stack to find file which calls require
    while info and info.what == "C" do
        info = debug.getinfo(i)
        i = i + 1
    end
    if not info then return "file with 'require' not found" end
    local path = info.short_src:match('^(.*/)[^/]+$')
    if not path then return loadfile(name) end
    return loadfile(path .. name)
end

-- this uses at least 40mb!!! FIXME
local orig_require = require
local function api_require(name) -- FIXME isnt this ugly in the stacktrace?
    if not name or not tostring(name):match('^%w') then
        return orig_require(name)
    else
        local success, mod, api
        -- try to namespace all modules within it/lib/rary/
        local apiname = name and 'it.' .. name or name
        success, api = pcall(orig_require, apiname)
        if success then return api end
        if not api:match('^module') then error(api) end
        success, mod = pcall(orig_require, name)
        if not success then error(api or mod) --[[error]] end
        return mod
    end
end

package.env = setmetatable({
    ['vanilla'] = function (env)
        -- copy loaders table to prevent luarocks from using api_loader
        local loaders = {}
        for k,v in pairs(getmetatable(env).loaders) do
            loaders[k] = v
        end
        package.loaders = loaders
        require = orig_require
    end,
    ['it'] = function (env)
        env('vanilla') -- remove any previously defined custom loaders
        table.insert(package.loaders, 1, local_loader)
        table.insert(package.loaders, 2, api_loader)
        require = api_require
    end,
    ['love'] = function (env, ...)
        env('it')
        local window = ...
        if window and window.type and window.type.name == 'it_windows' then
            require('prostitution').emulator(window)
        else -- start new window
            local gamepath = nil -- else process.argv[1]
            if type(window) == 'string' then gamepath = window end
            require('prostitution').__main(gamepath)
        end
    end,
}, {
    require = orig_require,
    loaders = package.loaders,
    __call = function (env, mode, ...)
        if  env[mode] then
            env[mode](env, ...)
        else
            error(string.format("unknown package environment '%s'!", mode))
        end
    end,
})


-- load luarocks loader if present
pcall(require, "luarocks.loader")
-- default
package.env('it')
