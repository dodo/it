local jit = require 'jit'

local doc = {}
local cache = {}

local funcinfo
local function push(typ, f, name, args, noval)
    if cache then
        table.insert(cache, {typ, f, name, args, noval})
    else
        if funcinfo then
            funcinfo[typ](f, name, args, noval)
        end
    end
end
jit.off(push)

function doc.info(f, name, args, noval)
    push('info',  f, name, args, noval)
    return doc
end
doc.info(doc.info, 'doc.info', '( function, name, args[, noValue] )')

function doc.todo(f, name, args, noval)
    push('todo',  f, name, args, noval)
    return doc
end
doc.info(doc.todo, 'doc.todo', '( function, name, args[, noValue] )')

function doc.private(f, name, args, noval)
    push('private',  f, name, args, noval)
    return doc
end
doc.info(doc.private, 'doc.private', '( function, name, args[, noValue] )')

function doc.deprecated(f, name, args, noval)
    push('deprecated',  f, name, args, noval)
    return doc
end
doc.info(doc.deprecated, 'doc.deprecated', '( function, name, args[, noValue] )')

function doc.init()
    funcinfo = require 'util.funcinfo'
    if funcinfo then
        local typ, f, name, args
        for _, queued in ipairs(cache) do
            typ, f, name, args, noval = unpack(queued)
            funcinfo[typ](f, name, args, noval)
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
