local ffi = require 'ffi'
local doc = require 'util.doc'

local function lazysubmodules(modname, names)
    modname = modname and (modname..'.') or ''
    local index = {}
    local module = {}
    for _, name in ipairs(names) do
        index[name] = function ()
            local submodule = require(modname .. name)
            module[name] = submodule -- prevents next __index call on this
            return submodule
        end
        doc.info(index[name],
                'require',
                string.format('( "%s%s" )', modname, name),
                true--[[noval]])
    end
    return setmetatable(module, {
        __metatable = index,
        __pairs = function ()
            return pairs(index)
        end,
        __ipairs = function ()
            return ipairs(names)
        end,
        __index = function (t, name)
            for _,n in ipairs(names) do
                if n == name then
                    return index[name]()
                end
            end
        end,
    })
end

local util = lazysubmodules('util', {'_ffi','bind', 'doc', 'fps', 'funcinfo',
    'luastate', 'misc', 'pixel', 'string', 'table', 'traverse'})

util.lazysubmodules = lazysubmodules
doc.info(lazysubmodules,
   'util.lazysubmodules', '( module_name, submodule_names )')

function util.xpcall(f, errhandler, ...)
    errhandler = errhandler or _TRACEBACK
    local result = {xpcall(f, errhandler, ...)} -- thanks to luajit
    local status = table.remove(result, 1)
    if status then return unpack(result) end
    if type(result) == 'string' then error(result) end
    if type(result) == 'cdata' and ffi.istype('const char*', result[1]) then
        error(ffi.string(result))
    end
    if type(result[1]) == 'cdata' and ffi.istype('const char*', result[1]) then
        error(ffi.string(result[1]))
    end
    if result[1] then error(result[1]) end
    -- else error ingored
end
doc.info(util.xpcall, 'util.xpcall', '( function, errhandler=_TRACEBACK, ... )')

function util.pcall(f, ...)
    return util.xpcall(f, _TRACEBACK, ...)
end
doc.info(util.pcall, 'util.pcall', '( function, ... )')

function util.dump(t)
    local color = require('console').color
    if not t then
        return color.bold .. color.red .. " -- nil" .. color.reset
    end
    local s = util.xpcall(function (t)
        local s = ""
        for k,v in pairs(t) do
            s = s .. color.magenta .. tostring(k) .. color.reset
                ..  " = "
                .. color.bold .. color.yellow ..  tostring(v) .. color.reset
                .. "\n"
        end
        return s
    end, function (err)
        if err:match("has no '__pairs' metamethod$") then return end
        return err
    end, t) or ""
    return color.bold .. color.red .. " -- \n" .. color.reset .. s
end
doc.info(util.dump, 'util.dump', '( table )')


return util
