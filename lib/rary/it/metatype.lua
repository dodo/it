local ffi = require 'ffi'
local util = require 'util'
local _ffi = require 'util._ffi'
local _type = require 'util.type'
local _table = require 'util.table'
local cface = require 'cface'
local Prototype = require 'prototype'
local doc = require 'util.doc'


local Metatype = Prototype:fork()
Metatype.bind = nil

local errors = {
    missing_decl = "missing declaration for symbol '%g*__init'",
    no_member = "has no member named '%g*__init'",
}

function Metatype:fork(proto)
    local fork = Prototype.fork(self, proto)
    -- no Metatype functions inside ctype plz
    fork.prototype = {}
    fork.__index = fork.prototype
    return fork
end
doc.info(Metatype.fork, 'Metatype:fork', '( proto={} )')

function Metatype:typedef(ct, name, db)
    if name then
        if db then
            db({ typedefs = name, verbose = process.verbose })
        else
            ct = cface.typedef(ct, name)
        end
    end
    local type = self:fork()
    type.name = name or ct
    if ct:match('^%s*void%s*%*%s*$') then
        type.ctype = require('util.bind').call(nil, ffi.new, ct)
    end
    return type
end
doc.info(Metatype.typedef, 'Metatype:typedef', '( ct, name=ct[, db] )')

function Metatype:struct(name, fields)
    local struct = self:fork()
    struct.name = name
    if _type.iscallable(fields) then
        local db = fields
        fields = nil
        db({
            typedefs = name,
            structs = '_' .. name,
            verbose = process.verbose
        })
    else
        cface.struct(name, fields)
    end
    return struct
end
doc.info(Metatype.struct, 'Metatype:struct', '( name, fields|db )')

function Metatype:use(clib, prefix, ct, gcname)
    local type = self:fork()
    prefix = prefix or ""
    type:lib(clib, prefix, gcname)
    return ct and type:overload(prefix .. ct) or type:new()
end
doc.info(Metatype.use, 'Metatype:use', '( clib|clibname, prefix, ct[, gcname] )')

function Metatype:overload(name)
    return cface.metatype(name, self)
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
    if self.__init then
        instance:__init(...)
    end
    return instance
end
doc.info(Metatype.initialize, 'type:initialize', '( instance, ... )')

function Metatype:virt(...)
    return self:initialize(setmetatable({}, self), ...)
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
    if self.__ac then
        return self.prototype.__ac()
    else
--         return self:ref(_ffi.new(self.name, ...))
        return self:ref(self.ctype(...))
    end
end
doc.info(Metatype.new, 'type:new', '( ... )')

function Metatype:ref(native)
    if self.__ref then
        self.prototype.__ref(ffi.cast('void*', native))
    end
    return native
end
doc.info(Metatype.ref, 'type:ref', '( native )')

function Metatype:unref(native)
    if self.__unref then
        native:__unref()
    end
    return native
end
doc.info(Metatype.unref, 'type:unref', '( native )')

function Metatype:ispointer(native, pointer)
    return native == self:cast(pointer)
end
doc.info(Metatype.ispointer, 'type:ispointer', '( native, pointer )')

local it_refs, it_unrefs
function Metatype:load(clib, cfunctions, db)
    local cname, cargs
    clib = cface.register(clib)
    for name, cdecl in pairs(cfunctions or {}) do
        -- use cached it_refs & it_unrefs
        if name == '__unref' and it_unrefs and cdecl:match('it_unrefs') then
            self.prototype[name] = it_unrefs
        elseif name == '__ref' and it_refs and cdecl:match('it_refs') then
            self.prototype[name] = it_refs
        else
            if db then
                cname = cdecl
                db({ functions = cname, verbose = process.verbose })
                local next = db({ functions = cname, find = true })
                local statement = next() -- hopefully the first one is the right one
                if statement then
                    cargs = statement.extent:gsub("^[^%(]*(.*)$", "%1")
                else
                    cargs = "(...)" -- unknown
                end
            else
                cface.declaration(cdecl .. ";")
                cname = cdecl:gsub("^%s*%S+%s+%*?([%w_]+)%s*%(.*$", "%1")
                cargs = cdecl:gsub("^[^%(]*(.*)$", "%1")
            end
            self.prototype[name] = clib[cname]
            doc.info(clib[cname], cname, cargs)
            -- cache it_refs & it_unrefs
            if name == '__unref' and cname == 'it_unrefs' then
                it_unrefs = clib[cname]
            elseif name == '__ref' and cname == 'it_refs' then
                it_refs = clib[cname]
            elseif name:match('^__') then
                self[name] = self.prototype[name]
            end
        end
    end
    return self
end
doc.info(Metatype.load, 'type:load', '( clib|clibname, cfunctions[, db] )')

function Metatype:lib(clib, prefix, gcname)
    local that = self
    clib = cface.register(clib)
    prefix = prefix or ""
    self.prefix = prefix
    self.prototype = clib
    self.__index = function (_, key)
        if key == 'metatype' then
            return that
        elseif key == 'prototype' then
            return clib
        else
            return clib[that.prefix .. key]
        end
    end
    jit.off(self.__index)
    if gcname then
        if prefix ~= "" then
            self.__gc = clib[prefix .. gcname]
        else
            self.__gc = function (...)
                return clib[that.prefix .. gcname](...)
            end
        end
    end
    return self
end
doc.info(Metatype.lib, 'type:lib', '( clib|clibname, prefix=""[, gcname] )')

function Metatype:api(metaname, cfunctions, apifile)
    cface.register(metaname, apifile or _it.api('api'))
    _ffi.get_define() -- cache function now, so package.env doesnt clash
    if not self.prototype._userdata then
        local data = _table.weak({})
        self.prototype._userdata = function (pointer)
            if data[pointer] then return data[pointer] end
            local userdata = _ffi.tolightuserdata(pointer)
            data[pointer] = userdata -- … and it's cached
            return userdata
        end
        doc.private(self.prototype._userdata, metaname..':_userdata', '( cdata )')
        jit.off(self.prototype._userdata)
    end
    local clib = debug.getregistry()[metaname].__index
    for _, name in ipairs(cfunctions) do
        local cfunction = clib[name]
        local _userdata = self.prototype._userdata
        self.prototype[name] = function (self, ...)
            return cfunction(_userdata(self), ...)
        end
        doc.info(self.prototype[name], metaname:lower()..':'..name, '( ... )')
        if name:match('^__') then
            self[name] = self.prototype[name]
        end
    end
end
doc.info(Metatype.api, 'type:api', '( metaname, cfunctions, apifile=_it.api("api") )')


return Metatype
