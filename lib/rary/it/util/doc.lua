local jit = require 'jit'

local doc = {}
local cache = {}


local function push(typ, f, name, args)
    if cache then
        table.insert(cache, {typ, f, name, args})
    else
        local funcinfo = debug.getregistry()._funcinfo
        if funcinfo then
            funcinfo[typ](f, name, args)
        end
    end
end
jit.off(push)

function doc.info(f, name, args)
    push('info',  f, name, args)
    return doc
end
doc.info(doc.info, 'doc.info', '( function, name, args )')

function doc.todo(f, name, args)
    push('todo',  f, name, args)
    return doc
end
doc.info(doc.todo, 'doc.todo', '( function, name, args )')

function doc.deprecated(f, name, args)
    push('deprecated',  f, name, args)
    return doc
end
doc.info(doc.deprecated, 'doc.deprecated', '( function, name, args )')

function doc.init()
    local funcinfo = debug.getregistry()._funcinfo
    if funcinfo then
        local typ, f, name, args
        for _, queued in ipairs(cache) do
            typ, f, name, args = unpack(queued)
            funcinfo[typ](f, name, args)
        end
    end
    cache = nil
end
doc.info(doc.init, 'doc.init', '(  )')

function doc.rm()
    cache = nil
end
doc.info(doc.rm, 'doc.rm', '(  )')


do
    for key,value in pairs(doc) do
        if type(value) == 'function' then
            jit.off(value)
        end
    end
end


return doc
