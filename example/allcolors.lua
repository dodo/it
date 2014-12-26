function allcolors()
--------------------------------------------------------------------------------
context.thread:safe()
math.randomseed(os.time())
local ffi = require 'ffi'
local util = require 'util'
local constrain = require('util.misc').constrain
local w, h = window.width, window.height
local done = false
print(w .. "x" .. h, "("..(w*h)..")")

ffi.cdef [[void *malloc(size_t size);void free(void *ptr);]]
ffi.cdef [[typedef struct coord {int x, y;} coord;]]
ffi.cdef [[typedef struct seed {int x, y; uint32_t c;} seed;]]
if ffi.abi 'le' then
    ffi.cdef [[typedef struct pixel { union u { uint32_t i; struct bgra {uint8_t b,g,r,a;} c; } u; } pixel;]]
else -- big endian
    ffi.cdef [[typedef struct pixel { union u { uint32_t i; struct argb {uint8_t a,r,g,b;} c; } u; } pixel;]]
end

SEEDS = SEEDS or 10000
function clean()
    done = false
    if coords then
        for i = 0,coords.len-1 do
            ffi.C.free(coords.pos[i])
        end
    end
    coords = { len = 0,
        size   = ffi.sizeof('coord'),
        pos    = ffi.new('coord*[?]', w * h),
        taken  = ffi.new('bool[?]',  w * h),
        marked = ffi.new('bool[?]',  w * h),
        seeds = { len = 0,
            size = ffi.sizeof('seed'),
            pos  = ffi.new('seed[?]', SEEDS), -- should be enougth for now
            all  = true,
        },
    }
    colors = { len = tonumber(0x00ffffff), fail = 0 }
    colors.data = ffi.new('uint32_t[?]', colors.len + 1)
    do local r,g,b = 0,0,0
        io.write("generate color table … ") io.flush()
        for i = 0, colors.len do
            colors.data[i] = i
        end
        io.write('done.\n')
    end
end


function unpackrgb(pixels, i)
    local c = ffi.new('pixel', {})
    c.u.i = pixels[i]
    return c.u.c.r,c.u.c.g,c.u.c.b,c.u.c.a
end

function rgb(r, g, b)
    local p = ffi.new('pixel', {})
    p.u.c.r, p.u.c.g, p.u.c.b = r, g, b
    return p
end


function open_coord(x, y)
    if not x or not y then return end
    if coords.marked[x + y * w] == true then return end
    local p = ffi.cast('coord*', ffi.C.malloc(coords.size))
    p.x = x
    p.y = y
    coords.pos[coords.len] = p
    coords.len = coords.len + 1
    coords.marked[x + y * w] = true
end

function pick_coord()
    if coords.len == 0 then return end
    local p,i
    while not i do
--         i = 0 -- FIXME FIXME this triggers the dead lock
        i =  math.random(coords.len) - 1
--         i = coords.len - 1
        p = coords.pos[i]
        if p == nil then
            coords.len = coords.len - 1
            if coords.len == 0 then return end
            coords.pos[i] = coords.pos[coords.len]
            i = nil
        end
--         if p == nil or coords.taken[p.x + p.y * w] == true then
--             i = nil
--         end
    end
    local x,y = p.x, p.y
    coords.taken[p.x + p.y * w] = true
--     coords.marked[p.x + p.y * w] = false
    -- remove from possible coords
    ffi.C.free(coords.pos[i])
    coords.len = coords.len - 1
    coords.pos[i] = coords.pos[coords.len]
    return x,y
end

function filter_coords(n,x,y, avail)
    local t = {}
    local i, _x, _y
    for ix = -n,n do
        for iy = -n,n do
            _x = x + ix
            _y = y + iy
            i = _x + _y * w

            if _x >= 0 and _y >= 0 and _x < w and _y < h then
                if (avail == true  and coords.taken[i] == true ) or
                   (avail == false and coords.taken[i] == false) then
                table.insert(t, {x=_x, y=_y, i=i})
                end
            end
        end
    end
    return t
end

function pick_color()
    if colors.len == 0 then return end
--     local i = 0
--     local i = colors.len - 1
    local i = math.random(colors.len) - 1
    local c = colors.data[i]
    -- remove from possible colors without breaking order
--     ffi.copy(colors.data + i, colors.data + i + 1, (colors.len - i))
    colors.len = colors.len - 1
    colors.data[i] = colors.data[colors.len]
    local p = ffi.new('pixel', {})
    p.u.i = c
    return p
end

function qsearch(x, arr, l, u)
    if l >= u then return end
    local i = math.floor((u - l) * 0.5) + l
        if not  arr[i] then return
    elseif x == arr[i] then return i
    elseif x <  arr[i] then return qsearch(x, arr, l, i-1)
    elseif x >  arr[i] then return qsearch(x, arr, i+1, u)
    end
end

function rm_color(c)
    if not c or colors.len == 0 then return end
    local i = qsearch(c.u.i, colors.data, 0, colors.len)
    if not i then return end
    -- remove from possible colors without breaking order
--     ffi.copy(colors.data + i, colors.data + i + 1, colors.len - i)
    colors.len = colors.len - 1
    colors.data[i] = colors.data[colors.len]
    return c
end

function seed(c, x, y)
    local i = math.random(colors.len) - 1
    if png then
        c = ffi.new('pixel', {})
        c.u.i = png.data[x + y * w]
        c = rm_color(c) or c
        c = c.u.i
    else
        c = c or colors.data[i]
    end

--     c = rm_color(c) or pick_color() or error("no color anymore!")
--     open_coord(x, y)
    coords.taken[x + y * w] = true
--     coords.marked[x + y * w] = true
    local s = coords.seeds.pos + coords.seeds.len
    coords.seeds.len = coords.seeds.len + 1
    s.c,s.x,s.y = c,x,y
end

function round(n)
  return math.floor((math.floor(n*2) + 1)/2)
end

-- TODO make fast with async and multiple threads
function iterate(pixels)
    local avgcol,x,y = ffi.new('pixel', {})
    if coords.seeds.all and coords.seeds.len > 0 then
        coords.seeds.len = coords.seeds.len - 1
        local s = coords.seeds.pos + coords.seeds.len
        avgcol.u.i,x,y = s.c,s.x,s.y
--         print('seed',avgcol.u.c.r,avgcol.u.c.g,avgcol.u.c.b,'.',x,y)
        if x + y * w < w * h then pixels[x + y * w] = s.c end
    elseif coords.len > 0 and colors.fail < 10 then
        x,y = pick_coord()
    elseif coords.seeds.len > 0 then
--         for i = 0,coords.len-1 do
--             coords.marked[coords.pos[i].x + coords.pos[i].y * w] = false
--         end
--         coords.len = 0
        colors.fail = 0
        coords.seeds.len = coords.seeds.len - 1
        local s = coords.seeds.pos + coords.seeds.len
        avgcol.u.i,x,y = s.c,s.x,s.y
--         print('seed',avgcol.u.c.r,avgcol.u.c.g,avgcol.u.c.b,'.',x,y)
        if x + y * w < w * h then pixels[x + y * w] = s.c end
    else
        x,y = pick_coord()
    end
    if not x then
        print"empty."
--         window:close()
        return
    end
    -- -- -- -- -- -- -- --
--     avgcol = pick_color() or error("no color anymore!")
    local n,r,g,b, _r,_g,_b = 0,0,0,0
    local neighbors = filter_coords(2 ,x,y, true --[[taken]])
    for _,neighbor in ipairs(neighbors) do
        _r,_g,_b = unpackrgb(pixels, neighbor.i)
        r = r + _r
        g = g + _g
        b = b + _b
        n = n + 1
    end
    if n > 0 then
--         local d = n
        n = 1 / (n - 1)
--         n = 1.4 / n
        avgcol.u.c.r = round(math.floor(r * n))
        avgcol.u.c.g = round(math.floor(g * n))
        avgcol.u.c.b = round(math.floor(b * n))
--         avgcol.u.c.r = constrain(math.floor(r * n), 0, 255)
--         avgcol.u.c.g = constrain(math.floor(g * n), 0, 255)
--         avgcol.u.c.b = constrain(math.floor(b * n), 0, 255)
--         print(d,'-',avgcol.u.c.r,avgcol.u.c.g,avgcol.u.c.b,'-',r,g,b,'-',avgcol.u.i)

        local a, i = avgcol
--         print(i,n,r,g,b)
        avgcol = rm_color(a)
        if not avgcol then
            avgcol = a
            if not coords.seeds.all then
                if r + g + b == 0 then
                    colors.fail = colors.fail + 1
                else
                    colors.fail = 0
                end
            end
        end
--         if not avgcol then
--             avgcol = a
--             if avgcol.u.i > colors.len then avgcol.u.i = colors.len - 1 end
--             i, avgcol.u.i = avgcol.u.i, colors.data[avgcol.u.i]
--             ffi.copy(colors.data + i, colors.data + i + 1, colors.len - i)
--             colors.len = colors.len - 1
--         end
--         local a = avgcol
--         avgcol = rm_color(avgcol)
--         if not avgcol then
--             if a.u.i < colors.len then
--                 a.u.i = colors.data[a.u.i]
--                 avgcol = rm_color(a)
--             end
--         end
--         avgcol = avgcol or pick_color() or error("no color anymore!")
    end
    for _,neighbor in ipairs(filter_coords(1,x,y, false --[[taken]])) do
        open_coord(neighbor.x, neighbor.y)
--         seed(avgcol, math.random(w), math.random(h)) -- FIXME
    end
    avgcol.u.c.a = 255
    return avgcol.u.i, x, y
end






local coiter
function reset()
    clean()
    io.write("start with " .. SEEDS .. " seeds … ")
    for i=1,SEEDS do
        seed(nil, math.random(w) - 1, math.random(h) - 1)
    end
--     seed(rgb(255,0,0), 0,0)
--     seed(rgb(0,255,0), math.floor(w*0.5), math.floor(w*0.5))
--     seed(rgb(0,0,255), w-1,h-1)
    io.write('done.\n')
    coiter = coroutine.create(function (pixels)
        local color, x,y = true
        while color do
            color,x,y = iterate(pixels)
            if color then
                pixels = coroutine.yield(color, x, y)
            end
        end
        reset()
    end)
end


print "" -- placeholder
window:pixels(function (pixels)
    local black = ffi.new('pixel')
    black.u.c.a = 255
    pixels = ffi.cast('uint32_t*', ffi.cast('void*', pixels))
--     ffi.fill(pixels, w * h * 4)
    for i=0,(w * h - 1) do
        pixels[i] = black.u.i
    end
end)
reset()



local steps = 1000
-- local steps = 50000
window:on('need render', function () -- {{{
    if done then
        print"" -- placeholder
        window.native:update()
        reset()
        return process:sleep(2)
    end
--     print"foo"
    local x,y,c
    window:pixels(function (pixels)
        pixels = ffi.cast('uint32_t*', ffi.cast('void*', pixels))
        for i = 1,steps do
            _,c,x,y = coroutine.resume(coiter, pixels)
            if c then pixels[x + y * w] = c else done = true break end
        end
        io.write("\rcolors left: " .. colors.len ..
                 "  coords left: " .. coords.len ..
                 "  seeds left: " .. coords.seeds.len .. " ")
        io.flush()
    end)
--     print"bar=============="
end)

window:on('close', function ()
    print "window closed …"
    window:write_to_png("allcolors.png")
    print"saved."
    process.exit()
end) -- }}}
--------------------------------------------------------------------------------
end

process:on('exit', function (code) print(code, "going down …") end)


window = require('window'):new()


local size = 200
-- local size = 768
-- local size = 512*2
-- local size = 4096
local width, height = size, size
-- local width, height = 1366, 786


if process.argv[#process.argv]:match('.png$') then
    local cairo = require 'cairo'
    png = {filename = process.argv[#process.argv]}
    png.surface = cairo.surface_from_png(png.filename)
    window.scope:define('png', png.surface.object, function ()
        local ffi = require 'ffi'
        local cairo = require 'cairo'
        png = {surface = {object = ffi.cast('cairo_surface_t*', _D.png)}}
        png.data = cairo.get_data(png.surface, 'uint32_t*')
        local width, height = cairo.get_size(png.surface)
        SEEDS = math.floor(width * height * 0.15)
    end)
    width, height = cairo.get_size(png.surface)
end

window.scope:import(allcolors)

window:open("allcolors", width, height)
print "window opened …"