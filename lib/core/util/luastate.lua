-- Copyright (c) 2011-2012 by Robert G. Jakabosky <bobby@neoawareness.com>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

local traverse = require("util.traverse").traverse
local sformat = string.format

local _M = {}

function _M.dump_stats(file)
	local type_cnts = {}
	local function type_inc(t)
		type_cnts[t] = (type_cnts[t] or 0) + 1
	end
	-- build metatable->type map for userdata type detection.
	local ud_types = {}
	local reg = debug.getregistry()
	for k,v in pairs(reg) do
		if type(k) == 'string' and type(v) == 'table' then
			ud_types[v] = k
		end
	end
	local function ud_type(ud)
		return ud_types[debug.getmetatable(ud)] or "type<unknown>"
	end
	local str_data = 0
	local funcs = {
	["edge"] = function(from, to, how, name)
		type_inc"type<edge>"
        if name then type_inc(name) end
--         if name then type_inc(tostring(name) .. ':' .. type(from) .. '→' .. type(to)) end
	end,
	["table"] = function(v)
		type_inc"type<table>"
	end,
	["string"] = function(v)
		type_inc"type<string>"
		str_data = str_data + #v
	end,
	["userdata"] = function(v)
		type_inc"type<userdata>"
		type_inc(ud_type(v))
	end,
	["cdata"] = function(v)
		type_inc"type<cdata>"
	end,
	["func"] = function(v)
		type_inc"type<function>"
	end,
	["thread"] = function(v)
		type_inc"type<thread>"
	end,
	}
	local ignores = {}
	for k,v in pairs(funcs) do
		ignores[#ignores + 1] = k
		ignores[#ignores + 1] = v
	end
	ignores[#ignores + 1] = type_cnts
	ignores[#ignores + 1] = funcs
	ignores[#ignores + 1] = ignores

	traverse(funcs, ignores)

	local fd = file
	if type(file) == 'string' then
		fd = io.open(filename, "w")
	end
	fd:write(sformat("memory = %i bytes\n", collectgarbage"count" * 1024))
	fd:write(sformat("str_data = %i\n", str_data))
	fd:write(sformat("object type counts:\n"))
    local values = {}
	for t,cnt in pairs(type_cnts) do
        table.insert(values, {cnt=cnt, t=t})
    end
    table.sort(values, function (a, b)
        return a.cnt > b.cnt
    end)
    for _, val in ipairs(values) do
		fd:write(sformat("  %23s = %9i\n", val.t, val.cnt))
	end
	fd:write("\n")
	--[[
	fd:write("LUA_REGISTRY dump:\n")
	for k,v in pairs(reg) do
		fd:write(tostring(k),'=', tostring(v),'\n')
	end
	--]]
	if type(file) == 'string' then
		fd:close()
	end
end

return _M
