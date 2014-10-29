local exports = {}


function exports.ininterval(v, min, max)
    return v >= min and v <= max
end

function exports.constrain(v, min, max)
    if     v < min then
           v = min
    elseif v > max then
           v = max
    end
    return v
end

function exports.lerp(p, a, b)
    return (b - a) * p + a
end


return exports
