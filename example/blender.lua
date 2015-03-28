-- start this in zbstudio with 'blend it' interpreter (misc/zbstudio/blender.lua)
-- even scratch pad works

function process.load()
    print "blender.lua"
    print(process.cwd())
    bpy = python.import 'bpy'
    utils = python.load 'blend_utils.py'

end

function process.setup()
    local view3d = python.asindx(
        utils.set_screen_layout(
            utils.get_current_view3d_scope(),
            "3D View Full")
    )
    local window = view3d['window']
    local screens = python.asindx(bpy.data.screens)
--    bpy.ops.view3d.viewnumpad{utils.get_current_view3d_scope(), type='CAMERA'}
--     bpy.ops.screen.screen_set{view3d, delta=1}
    -- enable ray tracer
    local scenes = python.asindx(bpy.data.scenes)
    scenes["Scene"].render.engine = "CYCLES"
    -- change viewport stuff
    local viewport = utils.get_current_space3d()
    viewport.show_manipulator = false
    viewport.viewport_shade = "MATERIAL"
--    viewport.viewport_shade = "WIREFRAME"
--    viewport.viewport_shade = "RENDERED"
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
--    bpy.ops.render.render()
    return 0.02 -- sleep
end
