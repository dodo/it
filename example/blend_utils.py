import re
from collections import Iterable, OrderedDict

import bpy


def typedkey(key, typ):
    if typ is '?':
        return key
    else:
        return re.sub('s$', '', key)


def store(name, node, keys, level, res):
    if select(node, keys, level, res):
        res[name] = node
        return True # else continue searching
    return False


def checktype(node, keys, level, res):
    if len(keys) < level + 1: return False
    key, typ = keys[level]
    if typ in ['*', '?'] or getattr(node, 'type', None) == typ:
        if querySelector(typedkey(key, typ), node, keys, level + 1, res):
            return True
    return False


def select(tree, keys, level, res):
    if tree is None: return False
    if len(keys) < level + 1: return True
    key, typ = keys[level]
    if hasattr(tree, key):
        leave = getattr(tree, key)
        if isinstance(leave, Iterable):
            for node in leave:
                if checktype(node, keys, level, res):
                    return True
        elif checktype(leave, keys, level, res):
            return True
    return False


def querySelector(name, tree, keys, level, res):
    if isinstance(tree, Iterable):
        for node in tree:
            if store(name, node, keys, level, res):
                return True
    elif store(name, tree, keys, level, res):
        return True
    return False


def querySelectorAll(path):
    if not isinstance(path, OrderedDict):
        raise ValueError("random generator in the wild detected!")
    tree = bpy.context.window_manager.windows # start point
    keys = list(path.items())
    res  = OrderedDict()
    querySelector('window', tree, keys, 0, res)
    return res


def get_current_screen_scope():
    return dict(querySelectorAll(OrderedDict([
        ('screen' , '?'),
    ])))


def get_current_view3d_scope():
    return dict(querySelectorAll(OrderedDict([
        ('screen' , '?'),
        ('areas'  , 'VIEW_3D'),
        ('regions', 'WINDOW'),
    ])))


def get_current_space3d():
    return querySelectorAll(OrderedDict([
        ('screen', '?'),
        ('areas' , 'VIEW_3D'),
        ('spaces', 'VIEW_3D'),
    ])).get('space', None)


def set_screen_layout(view3d, name):
    curname = view3d['screen'].name
    view3d['screen'] = bpy.data.screens[name]
    names = list(map(lambda t:t[0], bpy.data.screens.items()))
    old_i = names.index(curname)
    new_i = names.index(   name)
    delta = new_i - old_i
    bpy.ops.screen.screen_set(view3d, delta=delta)
    return view3d

def test():
    bpy.ops.mesh.primitive_monkey_add(radius=1, view_align=False, enter_editmode=False, location=(0, 0, 0), layers=(True, False, False, False, False, False, False, False, False, False, False, False, False, False, False, False, False, False, False, False))
    bpy.context.scene.render.engine = 'CYCLES'
    bpy.context.space_data.context = 'MATERIAL'
    bpy.ops.material.new()
    bpy.data.node_groups["Shader Nodetree"].nodes["Glass BSDF"].inputs[0].default_value = (0.8, 0.00768893, 0.0131234, 1)
    bpy.data.node_groups["Shader Nodetree"].nodes["Glass BSDF"].inputs[0].default_value = (0.8, 0.00768893, 0.0131234, 1)
    bpy.data.node_groups["Shader Nodetree"].nodes["Glass BSDF"].inputs[0].default_value = (0, 0.8, 0.0283517, 1)
    bpy.data.node_groups["Shader Nodetree"].nodes["Glass BSDF"].inputs[0].default_value = (0, 0.8, 0.0283517, 1)
    bpy.context.space_data.viewport_shade = 'RENDERED'


