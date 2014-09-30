local io = require 'io'

local fs = {}


function fs.read(filename)
    local file = io.open(filename, 'r')
    if not file then return end
    local content = file:read('*a')
    file:close()
    return content
end


return fs

