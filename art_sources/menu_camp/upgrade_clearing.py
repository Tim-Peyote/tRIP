"""Run through Blender MCP. Upgrade the existing clearing without moving its camp."""
import bpy
ROOT = '/Users/shaman/Desktop/Projects/Godot/TRIP'
scene = bpy.data.scenes.new('TRIP Menu Natural Clearing')
bpy.context.window.scene = scene
bpy.ops.import_scene.gltf(filepath=ROOT + '/assets/models/menu_camp/cedar_clearing.glb')
groves = [o for o in scene.objects if o.type == 'MESH' and o.name.startswith('Grove')]
sources = []
for filename in ['cedar', 'fir', 'wind_cedar']:
    before = set(scene.objects)
    bpy.ops.import_scene.gltf(filepath=ROOT + '/assets/models/taiga/' + filename + '.glb')
    imported = set(scene.objects) - before
    mesh = next(o for o in imported if o.type == 'MESH')
    sources.append(mesh.data)
    for obj in imported:
        bpy.data.objects.remove(obj, do_unlink=True)
for index, obj in enumerate(sorted(groves, key=lambda o: o.name)):
    obj.data = sources[index % len(sources)]
bpy.ops.object.select_all(action='DESELECT')
for obj in scene.objects:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=ROOT + '/assets/models/menu_camp/cedar_clearing.glb', export_format='GLB', use_selection=True, use_active_scene=True)
bpy.ops.wm.save_as_mainfile(filepath=ROOT + '/art_sources/menu_camp/natural_clearing.blend')
result = {'replaced_trees': len(groves), 'scene': scene.name}
