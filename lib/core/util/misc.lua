local doc = require 'util.doc'

local exports = {}


function exports.ininterval(v, min, max)
    return v >= min and v <= max
end
doc.info(exports.ininterval, 'util_misc.ininterval', '( value, min, max )')

function exports.constrain(v, min, max)
    if     v < min then
           v = min
    elseif v > max then
           v = max
    end
    return v
end
doc.info(exports.constrain, 'util_misc.constrain', '( value, min, max )')

function exports.lerp(p, a, b)
    return (b - a) * p + a
end
doc.info(exports.lerp, 'util_misc.lerp', '( percentage, min, max )')


return exports
