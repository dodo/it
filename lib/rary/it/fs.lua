local io = require 'io'
local doc = require 'util.doc'

local fs = {}


function fs.exists(filename)
    local file = io.open(filename, 'r')
    if not file then return false end
    file:close()
    return true
end
doc.info(fs.exists, 'fs.exists', '( filename )')

function fs.read(filename)
    local file = io.open(filename, 'r')
    if not file then return end
    local content = file:read('*a')
    file:close()
    return content
end
doc.info(fs.read, 'fs.read', '( filename )')

function fs.line(filename, from, to)
    local file = io.open(filename, 'r')
    if not file then return end
    local i = 0
    local content = {}
    for line in file:lines() do
        i = i + 1
        if to then
            if i >= from then
                table.insert(content, line)
            end
            if i >= to then
                break
            end
        elseif i == from then
            table.insert(content, line)
            break
        end
    end
    file:close()
    return table.concat(content, "\n"):gsub("%s*(.*)%s*", "%1")
end
doc.info(fs.line, 'fs.line', '( filename, at|from[, to ] )')


return fs

