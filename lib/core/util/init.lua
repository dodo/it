local ffi = require 'ffi'

local util = {}


function util.xpcall(f, errhandler, ...)
    local result = {xpcall(f, errhandler, ...)} -- thanks to luajit
--     print(result)
    local status = table.remove(result, 1)
    if status then return unpack(result) end
    if type(result) == 'string' then error(result) end
    if type(result) == 'cdata' then error(ffi.string(result)) end
    if type(result[1]) == 'cdata' then error(ffi.string(result[1])) end
    if result[1] then error(result[1]) end
    -- else error ingored
end

function util.pcall(f, ...)
    return util.xpcall(f, _TRACEBACK, ...)
end

function util.dump(t)
    local color = require('console').color
    local s = color.bold .. color.red .. " -- \n" .. color.reset
    for k,v in pairs(t) do
        s = s .. color.magenta .. tostring(k) .. color.reset
              ..  " = "
              .. color.bold .. color.yellow ..  tostring(v) .. color.reset
              .. "\n"
    end
    return s
end


return util
