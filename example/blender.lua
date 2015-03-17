-- start this in zbstudio with 'blend it' interpreter (misc/zbstudio/blender.lua)
-- even scratch pad works

function process.load()
    print "blender.lua"
    bpy = python.import 'bpy'
    python.execute("import sys; sys.path.append('"  .. process.cwd() .. "')")
    utils = python.import 'blend_utils'
    bpy.ops.view3d.viewnumpad{utils.get_current_view3d(), type='CAMERA'}
end

local function inc(t, k, i)
    t[k] = t[k] + i
end

local function rot(name, x, y, z)
    local object = python.asindx(bpy.data.objects)[name]
    local rotation = python.asindx(object.rotation_euler)
    inc(rotation, 0, x or  0.01)
    inc(rotation, 1, y or  0.01)
    inc(rotation, 2, z or  0.01)
end

function process.loop()
    local object, rotation
    rot('Cube', 0.01, 0.01, 0.01)
--    rot('Camera', 0.01, 0.01, 0.01)
    return 0.02 -- sleep
end
