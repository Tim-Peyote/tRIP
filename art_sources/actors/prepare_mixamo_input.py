"""Export the requested GEO base, unrigged, for external auto-rigging.
Does not upload anything or modify the source object / production GLBs.
"""
import bpy
from mathutils import Matrix, Vector
from pathlib import Path
root=Path('/Users/shaman/Desktop/Projects/Godot/TRIP/art_sources/actors')
source=bpy.data.objects.get('GEO-body_male_realistic')
if source is None:raise RuntimeError('GEO-body_male_realistic must be loaded')
scene=bpy.data.scenes.new('TRIP • Mixamo input');bpy.context.window.scene=scene
for original in [source]+list(source.children):
    if original.type!='MESH':continue
    ob=original.copy();ob.data=original.data.copy();scene.collection.objects.link(ob)
    relative=source.matrix_world.inverted()@original.matrix_world
    ob.parent=None;ob.matrix_world=Matrix.Identity(4);ob.animation_data_clear();ob.modifiers.clear();ob.vertex_groups.clear();ob.hide_set(False);ob.hide_render=False
    for v in ob.data.vertices:v.co=((relative@v.co)+Vector((0,0,.0056407065)))*(1.8/1.690083465073257)
    ob.select_set(True)
bpy.context.view_layer.objects.active=next(iter(scene.objects))
target=root/'geo_male_mixamo_input.fbx'
bpy.ops.export_scene.fbx(filepath=str(target),use_selection=True,object_types={'MESH'},bake_anim=False,axis_forward='-Z',axis_up='Y',add_leaf_bones=False)
result={'export':str(target),'rig':False,'uploaded':False}
