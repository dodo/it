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

function doc.rm()
    cache = nil
end

function doc.info(f, name, args)
    push('info',  f, name, args)
    return doc
end

function doc.todo(f, name, args)
    push('todo',  f, name, args)
    return doc
end

function doc.deprecated(f, name, args)
    push('deprecated',  f, name, args)
    return doc
end

return doc
