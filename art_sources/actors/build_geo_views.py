"""Additional presentation variants from the same GEO body, through Blender MCP."""
import bpy,bmesh,math
from pathlib import Path
from mathutils import Quaternion
ROOT=Path('/Users/shaman/Desktop/Projects/Godot/TRIP')
rig=bpy.data.objects['GEO Researcher Rig'];scene=rig.users_scene[0];bpy.context.window.scene=scene
def rotate(rig,name,x=0,y=0):
    p=rig.pose.bones[name];q=p.bone.matrix_local.to_quaternion();p.rotation_mode='QUATERNION';p.rotation_quaternion=q.inverted()@Quaternion((0,1,0),y)@Quaternion((1,0,0),x)@q
rig.animation_data.action=None
for old in list(rig.animation_data.nla_tracks):
    if old.name.startswith('Human Armature|Seated'):rig.animation_data.nla_tracks.remove(old)
for ob in rig.children:
    if ob.type=='MESH' and ob.name.startswith('Field trousers'):
        bm=bmesh.new();bm.from_mesh(ob.data)
        bmesh.ops.delete(bm,geom=[v for v in bm.verts if abs(v.co.x)>.27],context='VERTS');bm.to_mesh(ob.data);bm.free()
for t in rig.animation_data.nla_tracks:t.mute=True
for f in range(91):
    for p in rig.pose.bones:p.location=(0,0,0);p.rotation_mode='QUATERNION';p.rotation_quaternion=Quaternion()
    rig.pose.bones['Root'].location.y=-.46
    rotate(rig,'Spine',-.09+.01*math.sin(f/90*math.tau))
    for side,sign in [('L',1),('R',-1)]:
        rotate(rig,side+'Thigh',-1.45);rotate(rig,side+'Shin',1.45);rotate(rig,side+'Arm',-.5,sign*.2);rotate(rig,side+'Forearm',-.9)
    for p in rig.pose.bones:p.keyframe_insert('rotation_quaternion',frame=f+1);p.keyframe_insert('location',frame=f+1)
a=rig.animation_data.action;a.name='Human Armature|Seated';t=rig.animation_data.nla_tracks.new();t.name='Human Armature|Seated';t.strips.new(t.name,1,a);rig.animation_data.action=None
for t in rig.animation_data.nla_tracks:t.mute=False
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for o in rig.children:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/actors/geo_researcher.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animation_mode='NLA_TRACKS')
for t in rig.animation_data.nla_tracks:t.mute=True
fps=bpy.data.scenes.new('TRIP • GEO first person');bpy.context.window.scene=fps
if bpy.data.objects.get('arms'):bpy.data.objects['arms'].name='Archived GEO arms'
fr=rig.copy();fr.data=rig.data.copy();fr.name='arms';fr.animation_data_clear();fps.collection.objects.link(fr)
for p in fr.pose.bones:p.location=(0,0,0);p.rotation_quaternion=Quaternion()
objects=[]
for original in list(rig.children):
    if original.type!='MESH' or 'eye' in original.name.lower() or original.name.startswith('Field trousers'):continue
    for side in ['L','R']:
        ob=original.copy();ob.data=original.data.copy();ob.name='GEO_Arm_'+side+'_'+original.name;fps.collection.objects.link(ob);ob.parent=fr
        for mod in ob.modifiers:
            if mod.type=='ARMATURE':mod.object=fr
        groups={g.index for g in ob.vertex_groups if g.name in [side+'Arm',side+'Forearm',side+'Hand']}
        keep={v.index for v in ob.data.vertices if sum(g.weight for g in v.groups if g.group in groups)>.7}
        bm=bmesh.new();bm.from_mesh(ob.data);bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.index not in keep],context='VERTS');bm.to_mesh(ob.data);bm.free()
        if not ob.data.polygons:bpy.data.objects.remove(ob,do_unlink=True);continue
        objects.append(ob)
for side,sign in [('L',1),('R',-1)]:
    rotate(fr,side+'Arm',-1.0,sign*.22);rotate(fr,side+'Forearm',-.25)
bpy.context.view_layer.update()
# Bake the posed arm mesh and matching bone rest together, retaining weights.
bpy.ops.object.select_all(action='DESELECT')
for ob in objects:
    bpy.context.view_layer.objects.active=ob;ob.select_set(True)
    for m in list(ob.modifiers):
        if m.type=='ARMATURE':bpy.ops.object.modifier_apply(modifier=m.name)
    # Camera-specific shoulder continuation exits below the frame; don't expose
    # the open crop at the shoulder when looking along the forearm.
    upper={g.index for g in ob.vertex_groups if g.name in ['LArm','RArm']}
    for v in ob.data.vertices:v.co.z-=.5*sum(g.weight for g in v.groups if g.group in upper)
    ob.select_set(False)
fr.select_set(True);bpy.context.view_layer.objects.active=fr;bpy.ops.object.mode_set(mode='POSE');bpy.ops.pose.armature_apply(selected=False);bpy.ops.object.mode_set(mode='OBJECT')
for ob in objects:
    m=ob.modifiers.new('GEO skin','ARMATURE');m.object=fr;ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/actors/geo_first_person.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_sources/actors/geo_researcher.blend'))
result={'menu_clip':'Human Armature|Seated','fps_meshes':[o.name for o in objects]}
