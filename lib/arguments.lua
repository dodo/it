local util = require 'util'
local haz = require('util.table').index
local doc = require 'util.doc'


function process.prototype:usage()
    local usage = [[
Usage: it [options] [scripts.lua] [arguments]

Options:
  -m --main <module> require module and run module.__main function
  --repl             start a read-eval-print loop
  --debug            enable debug mode (jit.v,jit.dump)
]]
    if pcall(require, 'mobdebug') then
        usage = usage .. [[
  --mobdebug         enable remote debug mode (mobdebug)
]]
    end
    usage = usage .. [[
  --verbose          increase verbosity
  -v --version       print versions
  -h --help          magic flag
]]
    return usage
end
doc.info(process.prototype.usage, 'process.usage', '( )')

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

if haz(process.argv, "-h") or haz(process.argv, "--help") then
    print(process.usage())
    return process.exit()
end


if haz(process.argv, "-v") or haz(process.argv, "--version") then
    dofile(_it.libdir .. 'version.lua')
    return process.exit()
end

if haz(process.argv, "--verbose") then
    table.remove(process.argv, haz(process.argv, "--verbose"))
    process.verbose = true
end

if haz(process.argv, "--repl") then
    table.remove(process.argv, haz(process.argv, "--repl"))
    process.repl = true
end

if haz(process.argv, "--debug") then
    local color = require('console').color
    print(color.bold .. "[debug mode]" .. color.reset)
    table.remove(process.argv, haz(process.argv, "--debug"))
    local loaded, encoder = pcall(require, 'encoder')
    if loaded then encoder.debug('debug') end
    process.debug()
end

if haz(process.argv, "--mobdebug") then
    table.remove(process.argv, haz(process.argv, "--mobdebug"))
    if pcall(require, 'mobdebug') then
        local color = require('console').color
        print(color.bold .. "[remote debug mode]" .. color.reset)
        process.debug('remote')
    end
end

if haz(process.argv, "-m") or haz(process.argv, "--main") then
    local i = haz(process.argv, "-m") or haz(process.argv, "--main")
    table.remove(process.argv, i)
    local modulename = process.argv[i]
    table.remove(process.argv, i)
    doc.rm()
    return function --[[boot]]()
        local module = util.pcall(require, modulename)
        if not module.__main then
            print(string.format("module '%s' does not have a __main function.",
                                modulename))
            return process.exit(1)
        end
        local result = util.pcall(module.__main) -- could return a loop
        process.initialized = true
        return result
    end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

if #process.argv == 0 and process.argv[0] then
    process.repl = true
else
    process.script = process.argv[1]
end
