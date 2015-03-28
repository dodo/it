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

-- from http://stackoverflow.com/questions/15429236/how-to-check-if-a-module-exists-in-lua
function exports.exists(name, pkg)
    pkg = pkg or package
    if pkg.loaded[name] then return true end
    for _, searcher in ipairs(pkg.searchers or pkg.loaders) do
        local loader = searcher(name)
        if type(loader) == 'function' then
            pkg.preload[name] = loader
            return true
        end
    end
    return false
end
doc.info(exports.exists, 'util_module.exists', '( name[, pkg=package] )')


return exports
