local Process = dofile(_it.libdir .. 'process.lua')
local boot

process = Process:new()
package.loaded['it.process'] = process

if not process.native.islibrary then
    boot = dofile(_it.libdir .. 'arguments.lua')
end

-- called when finally initialized
return boot or loadfile(_it.libdir .. 'boot.lua')
