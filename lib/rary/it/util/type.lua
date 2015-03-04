local doc = require 'util.doc'

local exports = {}

function exports.iscallable(object)
    if not object then return false end
    if type(object) == 'function' then return true end
    local metatable = getmetatable(object)
    if metatable and metatable.__call then return true end
    return false
end
doc.info(exports.iscallable, 'util_type.iscallable', '( object )')

return exports

