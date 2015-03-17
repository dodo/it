local Process = dofile(_it.libdir .. 'process.lua')
local boot

process = Process:new()
package.loaded['it.process'] = process

boot = dofile(_it.libdir .. 'arguments.lua')

-- called when finally initialized
return boot or loadfile(_it.libdir .. 'boot.lua')
