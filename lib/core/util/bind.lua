local _table = require 'util.table'
local doc = require 'util.doc'

local exports = {}


local function ignore_self(this, self, ...)
    -- if function is called with : on the same object
    return self == this and {...} or {self, ...}
end
exports.ignore_self = ignore_self
doc.info(ignore_self, 'bind.ignore_self', '( this, self, ... )')

function exports.call(this, handler, ...)
    local args = this and {this, ...} or {...}
    if not this and #args == 0 then
        return handler
    elseif this and #args == 1 then
        return function (...)
            return handler(this, unpack(ignore_self(this, ...)))
        end
    elseif not this then
        return function (...)
            return handler(unpack(_table.sum(args, {...})))
        end
    else
        return function (...)
            -- append copies of the arguments
            return handler(unpack(_table.sum(args, ignore_self(this, ...))))
        end
    end
end
doc.info(exports.call, 'bind.call', '( this, handler, ... )')

return exports
