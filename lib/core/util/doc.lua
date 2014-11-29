local doc = {}

function doc.info(f, name, args)
    local funcinfo = debug.getregistry()._funcinfo
    if funcinfo then
       funcinfo:add(f, name, args)
    end
    return doc
end

return doc
