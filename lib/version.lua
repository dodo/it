local lines, logo = 1, {}
for line in require('util.string').gsplit([[
       ,.
       J;`.
      iyi.`.
     j?7;. :
    fclu:.` :
   dE2Xvi;. `.
  JGL56bhx;.';
  4KPY^f:l"`-;
    """l:;-""
       `; \
  itz  .' ;
      /'.'
     f .'
     `. \
      `-'
]], '\n') do logo[#logo+1] = line end

-- pretty print
local color = require('console').color
local function pprint(text)
    local line = logo[lines] or ""
    line =  line .. string.rep(' ', 16 - string.len(line))
    line = color.bold .. color.black .. line .. color.default
    lines = lines + 1
    print(line .. text)
end

-- print library versions
local format = require('util.table').format
local versions = _it.versions()
pprint(versions.it)
versions.it = nil

-- load lua versions
versions.cairo = require('lib.cairo').version()
versions.pixman = require('lib.pixman').version()
if pcall(require, 'mobdebug') then
    versions.mobdebug = format("{_NAME} {_VERSION}", require('mobdebug'))
end

-- print all versions
for lib,version in pairs(versions) do
    if lib == 'lua' then
        version = version .. " (running with " .. _VERSION .. ")"
    end
    pprint(" • " .. version)
end

-- print all plugin versions
for _,name in pairs({dofile(_it.libdir .. 'plugins.lua')}) do
    if name and _it.plugin[name] then
        local versions = _it.versions(_it.plugin[name].apifile)
        pprint(string.format("[%s]", versions.name))
        versions.name = nil
        for lib,version in pairs(versions) do
            pprint(" • " .. version)
        end
    end
end

-- print os info
pprint(format("running on {os} {arch}",require('jit')))

-- print whole logo
while lines < #logo do
    pprint("")
end
