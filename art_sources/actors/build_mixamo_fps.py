"""Camera representation using the downloaded Mixamo rig and Holding motion pose."""
import bpy,bmesh
from mathutils import Vector
from pathlib import Path
ROOT=Path('/Users/shaman/Desktop/Projects/Godot/TRIP')
source=bpy.data.objects['GEO Mixamo Rig'];scene=source.users_scene[0];bpy.context.window.scene=scene
for t in source.animation_data.nla_tracks:t.mute=t.name!='Human Armature|Holding'
scene.frame_set(15);bpy.context.view_layer.update()
# Bend the forearm at its real elbow instead of stretching skinned vertices.
for side in ['Right','Left']:
    bone=source.pose.bones['mixamorig:'+side+'ForeArm']
    direction=source.matrix_world.to_3x3() @ (bone.tail-bone.head)
    target=Vector((0,-.85,.45))
    world=source.matrix_world @ bone.matrix
    rotation=direction.rotation_difference(target).to_matrix().to_4x4()
    rotated=rotation @ world
    rotated.translation=world.translation
    bone.matrix=source.matrix_world.inverted() @ rotated
    bpy.context.view_layer.update()
pose={p.name:p.matrix.copy() for p in source.pose.bones}
fps=bpy.data.scenes.new('TRIP • Mixamo FPS');bpy.context.window.scene=fps
if bpy.data.objects.get('arms'):bpy.data.objects['arms'].name='Archived camera rig'
rig=source.copy();rig.data=source.data.copy();rig.name='arms';rig.animation_data_clear();fps.collection.objects.link(rig)
for p in rig.pose.bones:p.matrix=pose[p.name]
objects=[]
for original in source.children:
    if original.type!='MESH' or 'eye' in original.name.lower():continue
    for side,short in [('Left','L'),('Right','R')]:
        ob=original.copy();ob.data=original.data.copy();ob.name='GEO_Arm_'+short;fps.collection.objects.link(ob);ob.parent=rig
        for m in ob.modifiers:
            if m.type=='ARMATURE':m.object=rig
        groups={g.index for g in ob.vertex_groups if any(k in g.name for k in [side+'ForeArm',side+'Hand'])}
        keep={v.index for v in ob.data.vertices if sum(g.weight for g in v.groups if g.group in groups)>.7}
        bm=bmesh.new();bm.from_mesh(ob.data);bm.verts.ensure_lookup_table();bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.index not in keep],context='VERTS');bm.to_mesh(ob.data);bm.free();objects.append(ob)
bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT')
for ob in objects:
    ob.select_set(True);bpy.context.view_layer.objects.active=ob
    for m in list(ob.modifiers):
        if m.type=='ARMATURE':bpy.ops.object.modifier_apply(modifier=m.name)
    ob.select_set(False)
rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='POSE');bpy.ops.pose.armature_apply(selected=False);bpy.ops.object.mode_set(mode='OBJECT')
for ob in objects:m=ob.modifiers.new('Mixamo skin','ARMATURE');m.object=rig;ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/actors/geo_first_person.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_sources/actors/mixamo_downloads/geo_mixamo.blend'))
result={'bones':len(rig.data.bones),'meshes':len(objects)}
