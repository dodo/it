local util = require 'util'
local debug = require 'debug'
local _table = require 'util.table'
local doc = require 'util.doc'

local exports = {}

function exports.lazymodules(names, module)
    local modules = util.lazysubmodules(nil, names)
    if not module then return modules end
    local metatable = debug.getmetatable(module)
    _table.update(metatable.__metatable, getmetatable(modules))
    _table.append(metatable.names, names)
    return setmetatable(_table.copy(module), metatable)
end
doc.info(exports.lazymodules, 'util_module.lazymodules', '( names[, module] )')

return exports
