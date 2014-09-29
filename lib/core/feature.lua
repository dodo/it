local Prototype = require 'prototype'

local function merge(o, i) -- inplace
    local hidden = {}
    for _, p in ipairs(i) do
        for k, v in pairs(p) do
            if not (k == "prototype" or k == "metatable") then
                if o[k] and type(v) == 'function' then
                    if not hidden[k] then
                        hidden[k] = {o[k], v}
                        o[k] = function (...)
                            local ret = nil
                            for _,func in ipairs(hidden[k]) do
                                ret = func(...)
                            end
                            return ret
                        end
                    else
                        table.insert(hidden[k], v)
                    end
                else
                    o[k] = v
                end
                o.super[k] = o[k]
            elseif k == "prototype" and v ~= Prototype then
                if v.prototype then
                    merge(o, {v})
                else
                    merge(o, v)
                end
            end
        end
    end
    return o
end

local Features = Prototype:fork()

function Features:compose(protos)
    return Prototype:fork(merge({super={}}, protos))
end

return Features
