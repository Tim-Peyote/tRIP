"""Import actual downloaded Mixamo skin/rig/motion, not generated motion.
Run through Blender MCP. Raw FBX inputs remain local, excluded from git.
"""
import bpy, bmesh
from pathlib import Path
ROOT=Path('/Users/shaman/Desktop/Projects/Godot/TRIP');INPUT=ROOT/'art_sources/actors/mixamo_downloads'
scene=bpy.data.scenes.new('TRIP • Production Mixamo');bpy.context.window.scene=scene;scene.render.fps=30
bpy.ops.import_scene.fbx(filepath=str(INPUT/'geo_male_mixamo_input.fbx'))
rig=next(o for o in scene.objects if o.type=='ARMATURE')
if bpy.data.objects.get('GEO Mixamo Rig'):bpy.data.objects['GEO Mixamo Rig'].name='Archived Mixamo rig'
rig.name='GEO Mixamo Rig'
meshes=[o for o in scene.objects if o.type=='MESH']
# Mixamo's character FBX stores A-pose bind geometry plus a T-pose action.
# Animation-only FBXs bind in T-pose: bake both mesh and rest skeleton together.
scene.frame_set(1);bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT')
for ob in meshes:
    ob.select_set(True);bpy.context.view_layer.objects.active=ob
    for m in list(ob.modifiers):
        if m.type=='ARMATURE':bpy.ops.object.modifier_apply(modifier=m.name)
    ob.select_set(False)
rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='POSE');bpy.ops.pose.armature_apply(selected=False);bpy.ops.object.mode_set(mode='OBJECT');rig.animation_data_clear()
for ob in meshes:
    mod=ob.modifiers.new('Mixamo Skin','ARMATURE');mod.object=rig
def material(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.82
    return m
mats=[material('Mixamo GEO Skin',(.48,.30,.21)),material('Mixamo GEO Olive fabric',(.13,.18,.11)),material('Mixamo GEO Trousers',(.065,.075,.07)),material('Mixamo GEO Boots',(.065,.038,.023))]
for ob in meshes:
    ob.data.materials.clear()
    for m in mats:ob.data.materials.append(m)
    groups={g.index:g.name for g in ob.vertex_groups}
    for p in ob.data.polygons:
        p.use_smooth=True;counts={}
        for vi in p.vertices:
            for g in ob.data.vertices[vi].groups:counts[groups[g.group]]=counts.get(groups[g.group],0)+g.weight
        bone=max(counts,key=counts.get) if counts else ''
        p.material_index=0 if any(k in bone for k in ['Hand','Head','Neck']) or 'eye' in ob.name.lower() else (3 if any(k in bone for k in ['Foot','Toe']) else (2 if any(k in bone for k in ['Leg','Hips']) else 1))
clips={'Idle':'idle.fbx','Walk':'walking.fbx','Run':'standard run.fbx','Jump':'jump.fbx','Working':'pick fruit.fbx','Seated':'seated.fbx','Holding':'holding idle.fbx','StrafeLeft':'left strafe walking.fbx','StrafeRight':'right strafe walking.fbx'}
clips.update({'CrouchIdle':'crouch_idle.fbx','CrouchWalk':'crouch_walk.fbx'})
for name,file in clips.items():
    before=set(scene.objects);bpy.ops.import_scene.fbx(filepath=str(INPUT/file));new=set(scene.objects)-before
    src=next(o for o in new if o.type=='ARMATURE');action=src.animation_data.action.copy();action.name='Mixamo '+name
    # Same auto-rigged skeleton in every download; preserve authored bone motion.
    slot=action.slots[0];bag=action.layers[0].strips[0].channelbag(slot)
    for curve in bag.fcurves:
        if curve.data_path=='pose.bones["mixamorig:Hips"].location' and curve.array_index in [0,2]:
            start=curve.keyframe_points[0].co.y
            for k in curve.keyframe_points:k.co.y=start;k.handle_left.y=start;k.handle_right.y=start
    rig.animation_data_create();track=rig.animation_data.nla_tracks.new();track.name='Human Armature|'+name
    strip=track.strips.new(track.name,1,action);strip.action_slot=slot
    for ob in new:bpy.data.objects.remove(ob,do_unlink=True)
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for ob in meshes:ob.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/actors/geo_researcher.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animation_mode='NLA_TRACKS')
for t in rig.animation_data.nla_tracks:t.mute=True
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_sources/actors/mixamo_downloads/geo_mixamo.blend'))
result={'rig':rig.name,'bones':len(rig.data.bones),'animations':list(clips),'meshes':len(meshes)}
