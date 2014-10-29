local ffi = require 'ffi'
local util = require 'util'
local _table = require 'util.table'
local cface = require 'cface'
local Prototype = require 'prototype'

local Metatype = Prototype:fork()
Metatype.bind = nil

local errors = {
    missing_decl = "missing declaration for symbol '%g*init'",
    no_member = "has no member named '%g*init'",
}


local function __pairs(cdata)
    if not cdata then return end
    local i = 1
    return function (refct, key)
        local member = refct:member(i)
        if member then
            i = i + 1
            return member.name, cdata[member.name]
        end
    end, require('reflect').typeof(cdata), i
end

local function __ipairs(cdata)
    if not cdata then return end
    local i = 1
    return function (refct, key)
        local member = refct:member(i)
        if member then
            i = i + 1
            return i - 1, cdata[member.name]
        end
    end, require('reflect').typeof(cdata), i
end

function Metatype:fork(proto)
    local fork = Prototype.fork(self, proto)
    -- no Metatype functions inside ctype plz
    fork.prototype = {}
    fork.metatable.__index = fork.prototype
    fork.metatable.__ipairs = __ipairs
    fork.metatable.__pairs = __pairs
    return fork
end

function Metatype:typedef(ct, name)
    if name then ct = cface.typedef(ct, name) end
    local type = self:fork()
    type.name = name or ct
    if ct:match('^%s*void%s*%*%s*$') then
        type.ctype = require('util.bind').call(nil, ffi.new, ct)
    end
    return type
end

function Metatype:struct(name, fields)
    local type = self:fork()
    type.name = name
    cface.struct(name, fields)
    return type
end

function Metatype:use(clib, prefix, ct, gcname)
    local type = self:fork()
    type:lib(clib, prefix, gcname)
    return ct and type:overload(prefix .. ct) or type:new()
end

function Metatype:overload(name)
    return ffi.metatype(name, self.metatable)
end

function Metatype:cache()
    if not self.ctype then
        self.ctype = self:overload(self.name)
    end
    if not self.ptype then
        self.ptype = ffi.typeof(self.name .. '*')
    end
    return self
end

function Metatype:initialize(instance, ...)
    util.xpcall(function (...) if instance.init then instance:init(...) end end,
        function (err)
            -- ignore prefix
            if err:match(errors.missing_decl) or err:match(errors.no_member) then
                return nil -- ignore
            else
                return err
            end
        end, ...)
    return instance
end

function Metatype:virt(...)
    return self:initialize(setmetatable({}, self.metatable), ...)
end

function Metatype:create(pointer, ...)
    return self:initialize(self:ptr(pointer) or self:new(), ...)
end

function Metatype:ptr(address)
    if not address then return end
    if type(address) == 'cdata' or type(address) == 'userdata' then
        return self:cast(address)
    else
        error("can't cast given pointer address of type " .. type(address))
    end
end

function Metatype:cast(pointer)
    if not pointer then return end
    if not self.name then return self:virt() end
    self:cache()
    return cface.assert(self.ptype(pointer))
    -- already has metatable (i.e. LuaJIT rocks!)
end

function Metatype:new(...)
    if not self.name then return self:virt() end
    self:cache()
    return self.ctype(...)
end

function Metatype:load(clib, cfunctions)
    local cname
    clib = cface.register(clib)
    for name, cdecl in pairs(cfunctions) do
        cface.declaration(cdecl .. ";")
        cname = cdecl:gsub("^%s*%S+%s+%*?([%w_]+)%s*%(.*$", "%1")
        self.prototype[name] = clib[cname]
        if name:match('^__') then
            self.metatable[name] = self.prototype[name]
        end
    end
    return self
end

function Metatype:lib(clib, prefix, gcname)
    clib = cface.register(clib)
    prefix = prefix or ""
    self.prototype = clib
    self.metatable.__index = function (_, key)
        return clib[prefix .. key]
    end
    if gcname then
        self.metatable.__gc = clib[prefix .. gcname]
    end
    return self
end

local _define
local function lua_pushlightuserdata(name, pointer)
    if not _define then
        _define = Metatype:fork():load(_it.libdir .. "/api.so", {
            define = [[void it_defines_cdata_scope(void* ctx, const char* name,
                                             void* cdata)]];
        }):virt().define
    end
    _define(ffi.cast('void*', _it.state), name, ffi.cast('void*', pointer))
end
function Metatype:api(metaname, cfunctions)
    _it.loads(metaname)
    if not self.prototype._userdata then
        local data = _table.weak({})
        self.prototype._userdata = function (pointer)
            if data[pointer] then return data[pointer] end
            local tmp_name = "__tmp_userdata" .. math.random()
            lua_pushlightuserdata(tmp_name, pointer)
            local userdata = _G[tmp_name]
            _G[tmp_name] = nil
            data[pointer] = userdata -- … and it's cached
            return userdata
        end
    end
    local clib = debug.getregistry()[metaname].__index
    for _, name in ipairs(cfunctions) do
        local cfunction = clib[name]
        self.prototype[name] = function (self, ...)
            return cfunction(self._userdata(self), ...)
        end
        if name:match('^__') then
            self.metatable[name] = self.prototype[name]
        end
    end
end


return Metatype
