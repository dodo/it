local doc = require 'util.doc'

local exports = {}


function exports.ininterval(v, min, max)
    return v >= min and v <= max
end
doc.info(exports.ininterval, 'util_misc.ininterval', '( value, min, max )')

function exports.clamp(v, min, max)
    if     v < min then
           v = min
    elseif v > max then
           v = max
    end
    return v
end
doc.info(exports.clamp, 'util_misc.clamp', '( value, min, max )')

function exports.lerp(p, a, b)
    return (b - a) * p + a
end
doc.info(exports.lerp, 'util_misc.lerp', '( percentage, min, max )')

function exports.round(val, decimal)
  local exp = decimal and 10^decimal or 1
  return math.ceil(val * exp - 0.5) / exp
end
doc.info(exports.round, 'util_misc.round', '( value, decimal=1 )')

return exports
