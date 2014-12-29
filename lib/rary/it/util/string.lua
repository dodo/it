local doc = require 'util.doc'

local _string = {}


function _string.gsplit(s, sep, plain)
    local start = 1
    local done = false
    local function pass(i, j, ...)
        if i then
            local seg = s:sub(start, i - 1)
            start = j + 1
            return seg, ...
        else
            done = true
            return s:sub(start)
        end
    end
    return function()
        if done then return end
        if sep == '' then done = true return s end
        return pass(s:find(sep, start, plain))
    end
end
doc.info(_string.gsplit, 'util_string.gsplit', '( string, separator[, plain] )')


return _string
