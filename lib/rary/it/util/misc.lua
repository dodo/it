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

local function quick_search(x, arr, l, u)
    if l >= u then return end
    local i = math.floor((u - l) * 0.5) + l
        if not  arr[i] then return
    elseif x == arr[i] then return i
    elseif x <  arr[i] then return quick_search(x, arr, l, i-1)
    elseif x >  arr[i] then return quick_search(x, arr, i+1, u)
    end
end
exports.quick_search = quick_search
doc.info(exports.quick_search,
      'util_misc.quick_search',
      '( value, array, lower_bound, upper_bound )')

return exports
