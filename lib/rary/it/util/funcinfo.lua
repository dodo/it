local debug = require 'debug'
local ansi = require('console').color

-- function extra info {{{

local getmetatable = debug.getmetatable

local funcinfo = setmetatable( { }, { __mode = "k" } )

function funcinfo:add( f, name, args, _noval )
	-- add only if function actually exists
	-- (fun with functions that hop around between versions/implementations)
	if f then
		funcinfo[f] = { args, name }
		if _noval then
			funcinfo[f].noval = true
		end
	end
end
function funcinfo.info( f, name, args, noval )
	funcinfo:add( f, name, args, noval )
end

local function getFunctionParameters( f )
	-- try known info
	local info = funcinfo[f]
	if info then  return unpack( info )  end
	-- failing that, grab everything the debug interface gives us
	info = debug.getinfo( f, "nu" )
	local args = { }
	for i = 1, info.nparams do
		args[i] = ( debug.getlocal( f, i ) or "?x"..i )
	end
	if info.isvararg then  args[#args+1] = "..."  end
	args = (#args == 0) and "( )" or "( "..table.concat( args, ", " ).." )"
	-- add to info
	funcinfo[f] = { args, info.name }
	return args, info.name    -- name is usually nil
end

-- funcinfo for standard C functions (no meaningful prototype info) {{{

-- common functions

-- base library {{{

funcinfo:add( assert, 'assert','( v[, message, ...] )' )
funcinfo:add( error,   'error','( message[, level=1] )' )
funcinfo:add( pcall,   'pcall','( func[, ...] )' )
funcinfo:add( xpcall, 'xpcall','( func, errhandler[, ...] )' )

funcinfo:add( load,   'load','( src[, src_what[, mode="bt"[, env=_ENV]]] )' )
funcinfo:add( loadfile, 'loadfile','( filename[, mode="bt"[, env=_ENV]] )' )
funcinfo:add( dofile,     'dofile','( [filename=<stdin>] )' )

funcinfo:add( next,     'next','( table[, key] )' )
funcinfo:add( pairs,   'pairs','( val )' )
funcinfo:add( ipairs, 'ipairs','( val )' )

funcinfo:add( _G.getmetatable, 'getmetatable','( val )' )
funcinfo:add( setmetatable, 'setmetatable','( val, metatable )' )

funcinfo:add( type,         'type','( val )' )
funcinfo:add( rawget,     'rawget','( table, key )' )
funcinfo:add( rawset,     'rawset','( table, key, val )' )
funcinfo:add( rawequal, 'rawequal','( v1, v2 )' )
funcinfo:add( rawlen,     'rawlen','( val )' )
funcinfo:add( select,     'select','( index|"#", ... )' )

funcinfo:add( tonumber, 'tonumber','( val[, base=10] )' )
funcinfo:add( tostring, 'tostring','( val )' )
funcinfo:add( print,       'print','( ... )' )

funcinfo:add( collectgarbage, 'collectgarbage','( "collect|step|count|stop|..."[, arg] )' )

-- }}}

-- coroutine {{{

funcinfo:add( coroutine.create,   'coroutine.create','( func )' )
funcinfo:add( coroutine.wrap,       'coroutine.wrap','( func )' )
funcinfo:add( coroutine.resume,   'coroutine.resume','( coro, ... )' )
funcinfo:add( coroutine.yield,     'coroutine.yield','( ... )' )
funcinfo:add( coroutine.status,   'coroutine.status','( coro )' )
funcinfo:add( coroutine.running, 'coroutine.running','( )' )

-- }}}

-- modules {{{

funcinfo:add( require, 'require', '( modname )' )

funcinfo:add( package.loadlib,       'package.loadlib','( dylibname, openfuncname|"*" )' )
funcinfo:add( package.searchpath, 'package.searchpath','( name, path[, sep="."[, rep="/"]] )' )

-- }}}

-- string {{{

funcinfo:add( string.char, 'string.char','( ... )' )
funcinfo:add( string.byte, 'string.byte','( str[, i=1[, j=i]] )' )
funcinfo:add( string.sub,   'string.sub','( str, i=1[, j=-1] )' )

funcinfo:add( string.find,     'string.find','( str, pat[, i=1[, isPlain=false]] )' )
funcinfo:add( string.match,   'string.match','( str, pat[, i=1] )' )
funcinfo:add( string.gmatch, 'string.gmatch','( str, pat )' )
funcinfo:add( string.gsub,     'string.gsub','( str, pat[, replacement[, n]] )' )

funcinfo:add( string.lower,     'string.lower','( str )' )
funcinfo:add( string.upper,     'string.upper','( str )' )
funcinfo:add( string.reverse, 'string.reverse','( str )' )

funcinfo:add( string.len, 'string.len','( str )' )
funcinfo:add( string.rep, 'string.rep','( str, n[, sep=""] )' )

funcinfo:add( string.format, 'string.format','( fmt, ... )' )

funcinfo:add( string.dump, 'string.dump','( func )' )

-- }}}

-- table {{{

funcinfo:add( table.insert, 'table.insert','( arr[, key=#arr+1], val )' )
funcinfo:add( table.remove, 'table.remove','( arr[, key=#arr] )' )
funcinfo:add( table.sort,     'table.sort','( arr[, compfunc=(<)] )' )
funcinfo:add( table.concat, 'table.concat','( arr[, sep=""[, i=1[, j=#arr]]] )' )

funcinfo:add( table.pack,     'table.pack','( ... )' )
funcinfo:add( table.unpack, 'table.unpack','( t[, i=1[, j=#t]] )' )
funcinfo:add( unpack,             'unpack','( t[, i=1[, j=#t]] )' )

-- }}}

-- math {{{

do
	local function addop( name, args )
		funcinfo:add( math[name], 'math.'..name, '( '..args..' )' )
	end
	local function unop( name )  return addop( name, 'x' )  end
	for _,nm in pairs {
		'abs',  'acos', 'asin', 'atan', 'ceil', 'cos',  'cosh', 'deg',
		'exp', 'floor', 'modf', 'rad',  'sin',  'sinh', 'sqrt', 'tan',
		'tanh', 'frexp', 'randomseed', 'log10'
	} do  unop( nm )  end
	addop( 'atan2', 'y, x' )
	addop( 'fmod', 'x, y' )
	addop( 'ldexp', 'm, e' )
	addop( 'log', 'x[, base=e]' )
	addop( 'min', '...' )  addop( 'max', '...' )
	addop( 'pow', 'x, y' )
	addop( 'random', '[m[, n]]' )
end

-- }}}

-- io {{{

funcinfo:add( io.type, 'io.type','( val )' )

funcinfo:add( io.input,   'io.input','( [file] )' )
funcinfo:add( io.output, 'io.output','( [file] )' )

funcinfo:add( io.tmpfile, 'io.tmpfile', '( )' )

funcinfo:add( io.open,   'io.open','( filename[, mode="r"] )' )
funcinfo:add( io.popen, 'io.popen','( shellcmd[, mode="r"] )' )
funcinfo:add( io.close, 'io.close','( [file] )' )

funcinfo:add( io.read,    'io.input( ):read','( [...] )' )
funcinfo:add( io.write, 'io.output( ):write','( [...] )' )
funcinfo:add( io.flush, 'io.output( ):flush','( )' )

funcinfo:add( io.lines, 'io.lines','( [filename[, ...="*l"]] )' )

funcinfo:add( io.stdin.read,       '<file>:read','( [...="*l"] )' )
funcinfo:add( io.stdin.lines,     '<file>:lines','( [...="*l"] )' )
funcinfo:add( io.stdin.write,     '<file>:write','( ... )' )
funcinfo:add( io.stdin.seek,       '<file>:seek','( [base="cur"[, offset=0]] )' )
funcinfo:add( io.stdin.setvbuf, '<file>:setvbuf','( "no|full|line"[, bufsize] )' )
funcinfo:add( io.stdin.flush,     '<file>:flush','( )' )
funcinfo:add( io.stdin.close,     '<file>:close','( )' )

funcinfo:add( io.stdin.__gc, '<file>:__gc','( )' )
funcinfo:add( io.stdin.__tostring, '<file>:__tostring','( )' )

-- }}}

-- os {{{

funcinfo:add( os.clock, 'os.clock','( )' )
funcinfo:add( os.date,   'os.date','( [format="%c"[, time]] )' )
funcinfo:add( os.time,   'os.time','( [table] )' )

funcinfo:add( os.difftime, 'os.difftime','( t2, t1 )' )

funcinfo:add( os.execute, 'os.execute','( [shellcmd="true"] )' )
funcinfo:add( os.exit,       'os.exit','( [exitcode[, closeLState]] )' )
funcinfo:add( os.getenv,   'os.getenv','( varname )' )

funcinfo:add( os.remove,   'os.remove','( filename )' )
funcinfo:add( os.rename,   'os.rename','( from_name, to_name )' )
funcinfo:add( os.tmpname, 'os.tmpname','( )' )

funcinfo:add( os.setlocale, 'os.setlocale','( localename[, lc_cat="all"] )' )

-- }}}

-- debug {{{

funcinfo:add( debug.traceback, 'debug.traceback','( [coro,] [message=""[, level=1]] )' )

funcinfo:add( debug.debug, 'debug.debug','( )' )

funcinfo:add( debug.gethook, 'debug.gethook','( [coro] )' )
funcinfo:add( debug.sethook, 'debug.sethook','( [coro,] hook_func, mask[, count=0] )' )

funcinfo:add( debug.getregistry, 'debug.getregistry','( )' )

funcinfo:add( debug.getlocal,     'debug.getlocal','( [coro,] func|lvl, i )' )
funcinfo:add( debug.setlocal,     'debug.setlocal','( [coro,] lvl, i, val )' )
funcinfo:add( debug.getinfo,       'debug.getinfo','( [coro,] func|lvl[, what="flnStu"] )' )

funcinfo:add( debug.getupvalue,   'debug.getupvalue','( func, i )' )
funcinfo:add( debug.setupvalue,   'debug.setupvalue','( func, i, val )' )
funcinfo:add( debug.upvalueid,     'debug.upvalueid','( func, i )' )
funcinfo:add( debug.upvaluejoin, 'debug.upvaluejoin','( func1, i1, func2, i2 )' )

funcinfo:add( debug.getuservalue, 'debug.getuservalue','( udata )' )
funcinfo:add( debug.setuservalue, 'debug.getuservalue','( udata, val )' )

funcinfo:add( debug.getmetatable, 'debug.getmetatable','( val )' )
funcinfo:add( debug.setmetatable, 'debug.setmetatable','( val, metatable )' )

-- }}}

-- bit32 / bit {{{

if bit32 then
	funcinfo:add( bit32.bnot, 'bit32.bnot','( x )' )

	funcinfo:add( bit32.arshift, 'bit32.arshift','( x, shift )' )
	funcinfo:add( bit32.lrotate, 'bit32.lrotate','( x, shift )' )
	funcinfo:add( bit32.rrotate, 'bit32.rrotate','( x, shift )' )
	funcinfo:add( bit32.lshift,   'bit32.lshift','( x, shift )' )
	funcinfo:add( bit32.rshift,   'bit32.rshift','( x, shift )' )

	funcinfo:add( bit32.band,   'bit32.band','( ... )' )
	funcinfo:add( bit32.bor,     'bit32.bor','( ... )' )
	funcinfo:add( bit32.bxor,   'bit32.bxor','( ... )' )
	funcinfo:add( bit32.btest, 'bit32.btest','( ... )' )

	funcinfo:add( bit32.extract, 'bit32.extract','( x, bitoffset[, width=1])' )
	funcinfo:add( bit32.replace, 'bit32.replace','( x, subst, bitoffset[, width=1])' )
end

if bit then
	funcinfo:add( bit.tobit, 'bit.tobit','( x )' )
	funcinfo:add( bit.tohex, 'bit.tohex','( x[, +nhex|-NHEX=8] )' )
	funcinfo:add( bit.bswap, 'bit.bswap','( zzyyxx )' )

	funcinfo:add( bit.bnot, 'bit.bnot','( x )' )

	funcinfo:add( bit.arshift, 'bit.arshift','( x, shift )' )
	funcinfo:add( bit.rol,         'bit.rol','( x, shift )' )
	funcinfo:add( bit.ror,         'bit.ror','( x, shift )' )
	funcinfo:add( bit.lshift,   'bit.lshift','( x, shift )' )
	funcinfo:add( bit.rshift,   'bit.rshift','( x, shift )' )

	funcinfo:add( bit.band,   'bit.band','( ... )' )
	funcinfo:add( bit.bor,     'bit.bor','( ... )' )
	funcinfo:add( bit.bxor,   'bit.bxor','( ... )' )
end

-- }}}

-- jit {{{

if jit then
	funcinfo:add( jit.on,       'jit.on','( nil|func|true[, recursive] )' )
	funcinfo:add( jit.off,     'jit.off','( nil|func|true[, recursive] )' )
	funcinfo:add( jit.flush, 'jit.flush','( nil|i|func|true[, recursive] )' )

	funcinfo:add( jit.status, 'jit.status','( )' )

	if jit.opt then
		funcinfo:add( jit.opt.start, 'jit.opt.start','( [...] )' )
	end

	funcinfo:add( jit.attach, 'jit.attach','( cbfunc, "bc"|"trace"|"record"|"texit"|nil )' )
	-- cb_bytecode( func )
	-- cb_trace( "flush" )
	-- cb_trace( "stop",  traceno )
	-- cb_trace( "start", traceno, func, pc,  parenttraceno|nil, parentexitno|nil )
	-- cb_trace( "abort", traceno, func, pc,  abort_code, reason_string )
	-- cb_record( traceno, func, pc, inlining_depth )
	-- cb_texit( traceno, exitno, numgpregs, numfpregs )

	if jit.util then
		funcinfo:add( jit.util.funcinfo, 'jit.util.funcinfo','( attach_func, attach_pc )' )
	end

end

-- }}}

-- ffi {{{

do

local _, ffi = pcall( require, 'ffi' )
if _ and ffi then
	funcinfo:add( ffi.cdef, 'ffi.cdef','( csource )' )
	funcinfo:add( ffi.load, 'ffi.load','( libname[, global] )' )

	funcinfo:add( ffi.new,       'ffi.new','( ct[, nelem] [, init...] )' )
	funcinfo:add( ffi.cast,     'ffi.cast','( ct, init )' )
	funcinfo:add( ffi.typeof, 'ffi.typeof','( ct )' )

	funcinfo:add( ffi.gc, 'ffi.gc','( cdata, finalizer_func|nil )' )

	funcinfo:add( ffi.metatype, 'ffi.metatype','( ct, permanent_const_metatable )' )

	funcinfo:add( ffi.sizeof,     'ffi.sizeof','( ct[, nelem=1 ] )' )
	funcinfo:add( ffi.alignof,   'ffi.alignof','( ct )' )
	funcinfo:add( ffi.offsetof, 'ffi.offsetof','( ct, field )' )
	funcinfo:add( ffi.istype,     'ffi.istype','( ct, val )' )

	funcinfo:add( ffi.errno, 'ffi.errno','( [newerr=errno] )' )

	funcinfo:add( ffi.string, 'ffi.string','( ptr[, len] )' )
	funcinfo:add( ffi.copy,     'ffi.copy','( dest_ptr, src[, len=#src+1] )' )
	funcinfo:add( ffi.fill,     'ffi.fill','( dest_ptr, len[, fill_byte="\\0"] )' )

	funcinfo:add( ffi.abi, 'ffi.abi','( "32bit|64bit|le|be|fpu|softfp|hardfp|eabi|win" )' )

	local Cmt = getmetatable( ffi.C )
	funcinfo:add( Cmt.__gc,             '<C>:__gc','( )' )
	funcinfo:add( Cmt.__index,       '<C>:__index','( symname )' )
	funcinfo:add( Cmt.__newindex, '<C>:__newindex','( symname, _unknown )' )

	local NULL = ffi.cast( "void*", 0 )
	local ctmt = getmetatable( NULL )
	funcinfo:add( ctmt.__len, '<ffi_cdata>.__len','( v )' )
	funcinfo:add( ctmt.__unm, '<ffi_cdata>.__unm','( v )' )

	funcinfo:add( ctmt.__add, '<ffi_cdata>.__add','( v, w )' )
	funcinfo:add( ctmt.__sub, '<ffi_cdata>.__sub','( v, w )' )
	funcinfo:add( ctmt.__mul, '<ffi_cdata>.__mul','( v, w )' )
	funcinfo:add( ctmt.__div, '<ffi_cdata>.__div','( v, w )' )
	funcinfo:add( ctmt.__mod, '<ffi_cdata>.__mod','( v, w )' )
	funcinfo:add( ctmt.__pow, '<ffi_cdata>.__pow','( v, w )' )
	funcinfo:add( ctmt.__eq,   '<ffi_cdata>.__eq','( v, w )' )
	funcinfo:add( ctmt.__le,   '<ffi_cdata>.__le','( v, w )' )
	funcinfo:add( ctmt.__lt,   '<ffi_cdata>.__lt','( v, w )' )

	funcinfo:add( ctmt.__pairs,   '<ffi_cdata>.__pairs','( v )' )
	funcinfo:add( ctmt.__ipairs, '<ffi_cdata>.__ipairs','( v )' )

	funcinfo:add( ctmt.__tostring, '<ffi_cdata>.__tostring','( v )' )
	funcinfo:add( ctmt.__concat,     '<ffi_cdata>.__concat','( v, w )' )

	funcinfo:add( ctmt.__call, '<ffi_cdata>.__call','( v, ... )' )

	funcinfo:add( ctmt.__index,       '<ffi_cdata>.__index','( v, key )' )
	funcinfo:add( ctmt.__newindex, '<ffi_cdata>.__newindex','( v, key, val )' )

	-- TODO <callback>:free( )
	--      <callback>:set( func )
end

end

-- }}}

-- TODO gcinfo, newproxy, table.foreach, table.foreachi, table.getn
-- TODO jit.attach

-- deprecated {{{

local deprecated
do
	local deprecated_marker = " "..ansi.bold..ansi.yellow..ansi.on_red.."-DEPRECATED-"
	function deprecated( f, name, arg, ... )
		funcinfo:add( f, name, arg..deprecated_marker, ... )
	end
	funcinfo.deprecated = deprecated
end

deprecated( module, 'module','( modname[, ...] )' )
deprecated( package.seeall, 'package.seeall','( module )' )

-- }}}

-- private {{{

local private
do
    local private_marker = ansi.bold..ansi.black
    local private_note = " -PRIVATE-"
    function private( f, name, arg, ... )
        funcinfo:add( f, private_marker..name, private_marker..arg..private_note, ... )
    end
    funcinfo.private = private
end

-- }}}

-- todo {{{

local todo
do
	local todo_marker = " "..ansi.bold..ansi.yellow..ansi.on_blue.."-TODO-"
	function todo( f, name, arg, ... )
		funcinfo:add( f, name, arg..todo_marker, ... )
	end
	funcinfo.todo = todo
end

-- }}}

-- functions that differ significantly between versions
if _VERSION == "Lua 5.1" then
	-- Lua 5.1 or LuaJIT {{{
	funcinfo:add( getfenv, 'getfenv','( [func|lvl=1] )' )
	funcinfo:add( setfenv, 'setfenv','( func|lvl, table )' )

	funcinfo:add( debug.getfenv, 'debug.getfenv','( val )' )
	funcinfo:add( debug.setfenv, 'debug.setfenv','( val, table )' )

	funcinfo:add( loadstring, 'loadstring','( string[, src_what] )' )

	funcinfo:add( table.maxn, 'table.maxn','( table )' )

	if not jit then
		funcinfo:add( xpcall, 'xpcall','( func, errhandler )' )
		funcinfo:add( load,         'load','( func[, src_what] )' )
		funcinfo:add( loadfile, 'loadfile','( [filename=<stdin>] )' )
	end
	-- }}}
end

-- }}}

-- }}}

-- basic value highlighting:  show[type]( val, longForm? ) {{{

local show = { }
local hl
do
	local colors = {
		-- 'complex' data
		table = "blue", userdata = "red", cdata = "yellow",
		-- 'simple' data
		boolean = "green", number = "cyan", string = "red",
		-- code
		["function"] = "magenta", thread = "white",
	}
	function hl( x )  return colors[type( x )]  end

	local format = string.format
	local h0 = ansi.reset

	local c_nil = ansi.bold..ansi.black.."nil"..h0
	show["nil"] = function( )  return c_nil, "nil"  end

	local h_bool = ansi[colors.boolean]
	show.boolean = function( b )
		b = b and "true" or "false"
		return h_bool..b..h0, b
	end

	local h_num = ansi[colors.number]
	show.number = function( n, _longForm )
		n = tostring( n )
		return h_num..n..h0, n
	end

	local h_str = ansi[colors.string]
	show.string = function( s, _longForm )
		return h_str..s..h0, s
	end

	local h_fun = ansi[colors["function"]]
	show["function"] = function( f, _longForm )
		local s = tostring( f )
		if _longForm then
			local info = funcinfo[f]
			local arg, name = getFunctionParameters( f )
			if name and info and info.noval then s = name
			elseif name then  s = s..": "..name
			end
			s = s..arg
		end
		return h_fun..s..h0, s
	end

	local h_tab = ansi[colors.table]
	show.table = function( t, _longForm )
		local s = tostring( t )
		return h_tab..s..h0, s
	end

	local h_ud = ansi[colors.userdata]
	show.userdata = function( u, _longForm )
		local s = tostring( u )
		return h_ud..s..h0, s
	end

	local h_thr = ansi.bold .. ansi[colors.thread]
	show.thread = function( t, _longForm )
		local s = tostring( t )
		return h_thr..s..h0, s
	end

	local h_cd = ansi.bold .. ansi[colors.cdata]
	show.cdata = function( c, _longForm )
		local s = tostring( c )
		if _longForm then
			local info = funcinfo[c]
			if info then
				local arg, name = unpack(info)
				if name and info.noval then s = name
				elseif name then  s = s..": "..name
				end
				s = s..arg
			end
		end
		return h_cd..s..h0, s
	end
end

local function vshow( v, long )  return show[type( v )]( v, long )  end
local function headline( name, v )
	return ansi.bold..ansi.black..name..": "..ansi.reset..vshow( v, true )..ansi.reset
end

-- }}}

-- list : a better `for k,v in pairs(t) do print(k,v) end` {{{

local tab = "\t"
local function list( t, _short, _visited )
	local isTop = not _visited
	_visited = _visited or { }
	local result
	if _short or _visited[t] or (not pcall( pairs, t )) then
		-- no traversal
		result = (vshow( t, true ))
		if _short then  return result  end
	else
		-- traverse, align & sort output
		local colwidth, content = 0, { }
		for k, v in pairs( t ) do
			local kstr, rawk = vshow( k )
			local vstr       = vshow( v, true )
			if #rawk > colwidth then  colwidth = #rawk  end
			content[#content+1] = { rawk, kstr, vstr }
		end
		table.sort( content, function( a, b )  return a[1] < b[1]  end )
		colwidth = colwidth/8 + 1 ; colwidth = colwidth - colwidth%1
		local b = isTop and ansi.bold or ""
		for n, line in ipairs( content ) do
			local raw, k, v = line[1], line[2], line[3]
			local len = #raw/8 ; len = len - len%1
			local indent = tab:rep( colwidth-len )
			content[n] = b..k..indent..v
		end
		result = table.concat( content, "\n" )
		_visited[t] = true
	end
	-- check metatable
	local mt = getmetatable( t )
	if mt and not _visited[mt] then
		result = result.."\n\n"..headline( "<metatable>", mt )
		result = result.."\n"..list( mt, nil, _visited )
		local next = mt.__index
		if type( next ) == "table" and not _visited[next] then
			result = result.."\n\n"..headline( "__index", next )
			result = result.."\n"..list( next, nil, _visited )
		end
		local next = mt.__metatable
		if type( next ) == "table" and not _visited[next] then
			result = result.."\n\n"..headline( "__metatable", next )
			result = result.."\n"..list( next, nil, _visited )
		end
	end
	return result
end
funcinfo.list = list
funcinfo:add( list, 'list','( val[, shortFormat] )' )

-- }}}

do -- optional: "better" print {{{
	local select, list, concat, stdout = select, list, table.concat, io.stdout
	function funcinfo.print( ... )
		local arg = { ... }
		for i = 1, select( '#', ... ) do
			arg[i] = list( arg[i], true )
		end
		stdout:write( concat( arg, "\t" ), "\n" )
	end
	funcinfo:add( funcinfo.print, '_funcinfo.print','( ... )' )
	funcinfo.old_print = print
end -- }}}

return funcinfo

-- vim: set fdm=marker :
