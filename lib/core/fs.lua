local io = require 'io'

local fs = {}


function fs.exists(filename)
    local file = io.open(filename, 'r')
    if not file then return false end
    file:close()
    return true
end

function fs.read(filename)
    local file = io.open(filename, 'r')
    if not file then return end
    local content = file:read('*a')
    file:close()
    return content
end


return fs

