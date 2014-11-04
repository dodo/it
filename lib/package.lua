-- preload ffi core module into cache
require 'ffi'

-- prepend to lua search paths
package.path = './?/init.lua;' .. package.path

-- add new path to api libs (core + plugins)
package.apipath = _it.libdir .. 'core/?/init.lua'
package.apipath = _it.libdir .. 'core/?.lua;' .. package.apipath

-- load all plugin meta information
_it.plugin = {}
for _,name in pairs({dofile(_it.libdir .. 'plugins.lua')}) do
    if name then
        local plugin = {}
        plugin.path = _it.plugindir .. name .. '/'
        plugin.libdir = plugin.path .. 'lib/'
        plugin.apifile = 'lib' .. name .. '.so'
        package.apipath = package.apipath .. ';'
            .. plugin.libdir .. 'core/?.lua;'
            .. plugin.libdir .. 'core/?/init.lua'
        _it.plugin[name] = plugin
    end
end

-- load luarocks loader if present
pcall(require, "luarocks.loader")
-- copy loaders table to prevent luarocks from using api_loader
do local loaders = {}
    for k,v in pairs(package.loaders) do
        loaders[k] = v
    end
    package.loaders = loaders
end

--create api loader
local function api_loader(name)
    local path, err = package.searchpath(name, package.apipath)
    if not path then return err end
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

-- add new loaders
table.insert(package.loaders, 1, local_loader)
table.insert(package.loaders, 2, api_loader)
