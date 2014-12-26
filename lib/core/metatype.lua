local ffi = require 'ffi'
local util = require 'util'
local _table = require 'util.table'
local cface = require 'cface'
local Prototype = require 'prototype'
local doc = require 'util.doc'


local Metatype = Prototype:fork()
Metatype.bind = nil

local errors = {
    missing_decl = "missing declaration for symbol '%g*init'",
    no_member = "has no member named '%g*init'",
}

function Metatype:fork(proto)
    local fork = Prototype.fork(self, proto)
    -- no Metatype functions inside ctype plz
    fork.prototype = {}
    fork.metatable.__index = fork.prototype
    return fork
end
doc.info(Metatype.fork, 'Metatype:fork', '( proto={} )')

function Metatype:typedef(ct, name)
    if name then ct = cface.typedef(ct, name) end
    local type = self:fork()
    type.name = name or ct
    if ct:match('^%s*void%s*%*%s*$') then
        type.ctype = require('util.bind').call(nil, ffi.new, ct)
    end
    return type
end
doc.info(Metatype.typedef, 'Metatype:typedef', '( ct, name=ct )')

function Metatype:struct(name, fields)
    local type = self:fork()
    type.name = name
    cface.struct(name, fields)
    return type
end
doc.info(Metatype.struct, 'Metatype:struct', '( name, fields )')

function Metatype:use(clib, prefix, ct, gcname)
    local type = self:fork()
    type:lib(clib, prefix, gcname)
    return ct and type:overload(prefix .. ct) or type:new()
end
doc.info(Metatype.use, 'Metatype:use', '( clib|clibname, prefix, ct[, gcname] )')

function Metatype:overload(name)
    return cface.metatype(name, self.metatable)
end
doc.info(Metatype.overload, 'type:overload', '( name )')

function Metatype:cache()
    if not self.ctype then
        self.ctype = self:overload(self.name)
    end
    if not self.ptype then
        self.ptype = ffi.typeof(self.name .. '*')
    end
    return self
end
doc.info(Metatype.cache, 'type:cache', '(  )')

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
doc.info(Metatype.initialize, 'type:initialize', '( instance, ... )')

function Metatype:virt(...)
    return self:initialize(setmetatable({}, self.metatable), ...)
end
doc.info(Metatype.virt, 'type:virt', '( ... )')

function Metatype:create(pointer, ...)
    return self:initialize(self:ptr(pointer) or self:new(), ...)
end
doc.info(Metatype.create, 'type:create', '( nil|pointer, ... )')

function Metatype:ptr(address)
    if not address then return end
    if type(address) == 'cdata' or type(address) == 'userdata' then
        return self:cast(address)
    else
        error("can't cast given pointer address of type " .. type(address))
    end
end
doc.info(Metatype.ptr, 'type:ptr', '( address )')

function Metatype:cast(pointer)
    if not pointer then return end
    if not self.name then return self:virt() end
    self:cache()
    return cface.assert(self:ref(self.ptype(pointer)))
    -- already has metatable (i.e. LuaJIT rocks!)
end
doc.info(Metatype.cast, 'type:cast', '( pointer )')

function Metatype:new(...)
    if not self.name then return self:virt() end
    self:cache()
    return self:ref(self.ctype(...))
end
doc.info(Metatype.new, 'type:new', '( ... )')

function Metatype:ref(native)
    if self.prototype.ref then
        self.prototype.ref(ffi.cast('void*', native))
    end
    return native
end
doc.info(Metatype.ref, 'type:ref', '( native )')

function Metatype:unref(native)
    if self.prototype.unref then
        native:unref()
    end
    return native
end
doc.info(Metatype.unref, 'type:unref', '( native )')

function Metatype:ispointer(native, pointer)
    return native == self:cast(pointer)
end
doc.info(Metatype.ispointer, 'type:ispointer', '( native, pointer )')

function Metatype:load(clib, cfunctions)
    local cname, cargs
    clib = cface.register(clib)
    for name, cdecl in pairs(cfunctions or {}) do
        cface.declaration(cdecl .. ";")
        cname = cdecl:gsub("^%s*%S+%s+%*?([%w_]+)%s*%(.*$", "%1")
        cargs = cdecl:gsub("^[^%(]*(.*)$", "%1")
        self.prototype[name] = clib[cname]
        doc.info(clib[cname], cname, cargs)
        if name:match('^__') then
            self.metatable[name] = self.prototype[name]
        end
    end
    return self
end
doc.info(Metatype.load, 'type:load', '( clib|clibname, cfunctions )')

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
doc.info(Metatype.lib, 'type:lib', '( clib|clibname, prefix=""[, gcname] )')

local _define
local function lua_pushlightuserdata(name, pointer)
    if not _define then
        _define = Metatype:fork():load('api', {
            define = [[void it_defines_cdata_scope(void* ctx, const char* name,
                                             void* cdata)]];
        }):virt().define
    end
    _define(_D._it_scopes_, name, ffi.cast('void*', pointer))
end
function Metatype:api(metaname, cfunctions, apifile)
    cface.register(metaname, apifile or 'libapi.so')
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
        local _userdata = self.prototype._userdata
        self.prototype[name] = function (self, ...)
            return cfunction(_userdata(self), ...)
        end
        if name:match('^__') then
            self.metatable[name] = self.prototype[name]
        end
    end
end
doc.info(Metatype.api, 'type:api', '( metaname, cfunctions, apifile="libapi.so" )')


return Metatype
