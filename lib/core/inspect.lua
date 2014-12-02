local reflect = require 'reflect'
local doc = require 'util.doc'

local inspect = {}


function inspect.value(refct, cdata)
    if refct.what == 'constant' then
        return refct.value
    end
    return cdata[refct.name]
end
doc.info(inspect.value, 'inspect.value', '( refct, cdata )')

function inspect.typeofelement(cdata)
    local refct = reflect.typeof(cdata)
    while refct.what == 'ptr' or refct.what == 'ref' do
        refct = refct.element_type
    end
    return refct
end
doc.info(inspect.typeofelement, 'inspect.typeofelement', '( cdata )')

function inspect.pairs(cdata)
    if not cdata then return end
    local refct = inspect.typeofelement(cdata)
    if refct.siblings then
        local next, _, ct = refct:siblings()
        return function ()
            ct = next(_, ct)
            if ct then return ct.name, inspect.value(ct, cdata) end
        end
    end
end
doc.info(inspect.pairs, 'inspect.pairs', '( cdata )')

function inspect.ipairs(cdata)
    if not cdata then return end
    local refct = inspect.typeofelement(cdata)
    if refct.siblings then
        local i = 0
        local next, _, ct = refct:siblings()
        return function ()
            i = i + 1
            ct = next(_, ct)
            if ct then return i, inspect.value(ct, cdata) end
        end
    end
end
doc.info(inspect.ipairs, 'inspect.ipairs', '( cdata )')


return inspect
