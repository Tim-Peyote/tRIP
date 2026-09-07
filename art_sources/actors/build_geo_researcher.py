"""Run in live Blender through MCP. Preserve user's GEO base mesh; export a rigged copy.
The source body must already exist in bpy.data.objects. Metres, facing -Y / Godot +Z.
"""
import bpy, bmesh, math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT=Path('/Users/shaman/Desktop/Projects/Godot/TRIP')
source=bpy.data.objects.get('GEO-body_male_realistic')
if source is None: raise RuntimeError('Missing requested GEO-body_male_realistic source')
scene=bpy.data.scenes.new('TRIP • GEO realistic researcher')
bpy.context.window.scene=scene
scene.render.fps=30
body=source.copy();body.data=source.data.copy();body.name='GEO Researcher Body'
scene.collection.objects.link(body);body.parent=None;body.matrix_world=Matrix.Identity(4)
body.hide_set(False);body.hide_render=False
body.modifiers.clear();body.vertex_groups.clear()
factor=1.80/(1.6844427585601807+.005640706513077021)
for v in body.data.vertices:v.co=(v.co+Vector((0,0,.0056407065)))*factor
for p in body.data.polygons:p.use_smooth=True
def mat(name,color,rough=.8):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough
    return m
skin=mat('GEO • skin',(.48,.30,.21));jacket=mat('GEO • field olive',(.13,.18,.11));trousers=mat('GEO • charcoal fabric',(.065,.075,.07));leather=mat('GEO • dark leather',(.065,.038,.023));eye=mat('GEO • eyes',(.28,.24,.19),.3)
body.data.materials.clear();body.data.materials.append(skin)
ar=bpy.data.armatures.new('GEO Anatomical Skeleton');rig=bpy.data.objects.new('GEO Researcher Rig',ar);scene.collection.objects.link(rig)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
bones=[('Root',(0,0,0),(0,0,.15),None),('Hips',(0,0,.91),(0,0,1.04),'Root'),('Spine',(0,0,1.04),(0,0,1.23),'Hips'),('Chest',(0,0,1.23),(0,0,1.44),'Spine'),('Neck',(0,0,1.44),(0,0,1.55),'Chest'),('Head',(0,0,1.55),(0,0,1.77),'Neck')]
for side,sign in [('L',1),('R',-1)]:
    def pt(x,y,z):return (x*sign,y,z)
    bones.extend([(side+'Thigh',pt(.105,0,.94),pt(.135,-.015,.52),'Hips'),(side+'Shin',pt(.135,-.015,.52),pt(.15,.015,.12),side+'Thigh'),(side+'Foot',pt(.15,.015,.12),pt(.15,-.13,.055),side+'Shin'),(side+'Clavicle',pt(.04,0,1.43),pt(.185,0,1.43),'Chest'),(side+'Arm',pt(.185,0,1.43),pt(.305,-.005,1.18),side+'Clavicle'),(side+'Forearm',pt(.305,-.005,1.18),pt(.405,-.02,.99),side+'Arm'),(side+'Hand',pt(.405,-.02,.99),pt(.43,-.03,.90),side+'Forearm')])
for name,h,t,parent in bones:
    b=ar.edit_bones.new(name);b.head=h;b.tail=t
    if parent:b.parent=ar.edit_bones[parent]
    if name=='Root':b.use_deform=False
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
unweighted=[v.index for v in body.data.vertices if not v.groups]
if unweighted:raise RuntimeError('Automatic skinning left vertices unweighted: '+str(len(unweighted)))
meshes=[body]
for child in source.children:
    if child.type!='MESH':continue
    ob=child.copy();ob.data=child.data.copy();scene.collection.objects.link(ob);ob.parent=None;ob.matrix_world=Matrix.Identity(4);ob.modifiers.clear();ob.vertex_groups.clear()
    relative=source.matrix_world.inverted()@child.matrix_world
    for v in ob.data.vertices:v.co=((relative@v.co)+Vector((0,0,.0056407065)))*factor
    ob.parent=rig;vg=ob.vertex_groups.new(name='Head');vg.add(list(range(len(ob.data.vertices))),1,'REPLACE');mod=ob.modifiers.new('Skin','ARMATURE');mod.object=rig
    ob.data.materials.clear();ob.data.materials.append(eye);ob.hide_render=False;ob.hide_set(False);meshes.append(ob)
# Simple separate garment shells preserve the anatomical silhouette and skin weights.
def shell(name,predicate,material,offset):
    ob=body.copy();ob.data=body.data.copy();ob.name=name;scene.collection.objects.link(ob)
    bm=bmesh.new();bm.from_mesh(ob.data)
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if not predicate(f.calc_center_median())],context='FACES')
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bm.normal_update()
    for v in bm.verts:v.co+=v.normal*offset
    bm.to_mesh(ob.data);bm.free();ob.data.materials.clear();ob.data.materials.append(material)
    for p in ob.data.polygons:p.material_index=0
    solid=ob.modifiers.new('Garment thickness','SOLIDIFY');solid.thickness=.004
    meshes.append(ob)
shell('Field jacket',lambda p:.97<p.z<1.49,jacket,.015)
shell('Field trousers',lambda p:.19<p.z<1.00 and abs(p.x)<.27,trousers,.013)
shell('Boots',lambda p:p.z<.25,leather,.019)
# In-place cycles. World-axis rotations are converted into each bone's local basis.
def rotate(name,rx=0,ry=0,rz=0):
    b=rig.pose.bones[name];basis=b.bone.matrix_local.to_quaternion()
    q=Quaternion((0,0,1),rz)@Quaternion((0,1,0),ry)@Quaternion((1,0,0),rx)
    b.rotation_mode='QUATERNION';b.rotation_quaternion=basis.inverted()@q@basis
for state,duration in [('Idle',90),('Walk',36),('Run',24),('Jump',36),('Working',60),('Death',45)]:
    rig.animation_data_create();rig.animation_data.action=None
    for track in rig.animation_data.nla_tracks:track.mute=True
    for frame in range(duration+1):
        t=frame/duration;phase=t*math.tau
        for pb in rig.pose.bones:pb.location=(0,0,0);pb.rotation_mode='QUATERNION';pb.rotation_quaternion=Quaternion()
        for side,sign in [('L',1),('R',-1)]:
            stride=math.sin(phase+(0 if sign==1 else math.pi))
            swing=.0;knee=.035;arm=.025*math.sin(phase)
            if state in ['Walk','Run']:
                swing=stride*(.38 if state=='Walk' else .65)
                knee=max(0,-stride)*(.62 if state=='Walk' else 1.05)+.035
                arm=-swing*.7
            elif state=='Jump':swing=-.25*math.sin(math.pi*t);knee=.6*math.sin(math.pi*t);arm=-.7*math.sin(math.pi*t)
            elif state=='Working':arm=-.7+.12*math.sin(phase)
            rotate(side+'Thigh',swing);rotate(side+'Shin',-knee);rotate(side+'Foot',knee*.65-swing*.3)
            rotate(side+'Arm',arm,sign*.27);rotate(side+'Forearm',-.15 if state!='Run' else -.8)
        rotate('Spine',.025*math.sin(phase) if state=='Idle' else (.12 if state=='Run' else .025))
        if state in ['Walk','Run']:rig.pose.bones['Hips'].location.y=.012*(1-math.cos(phase*2))
        if state=='Death':rotate('Root',-1.4*min(1,t*1.4))
        for pb in rig.pose.bones:
            pb.keyframe_insert('rotation_quaternion',frame=frame+1);pb.keyframe_insert('location',frame=frame+1)
    action=rig.animation_data.action;action.name='Human Armature|'+state
    track=rig.animation_data.nla_tracks.new();track.name='Human Armature|'+state;track.strips.new(track.name,1,action);track.mute=True;rig.animation_data.action=None
for pb in rig.pose.bones:pb.location=(0,0,0);pb.rotation_quaternion=Quaternion()
for track in rig.animation_data.nla_tracks:track.mute=False
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for ob in meshes:ob.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/actors/geo_researcher.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animation_mode='NLA_TRACKS')
for track in rig.animation_data.nla_tracks:track.mute=True
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_sources/actors/geo_researcher.blend'))
result={'source':source.name,'body_vertices':len(body.data.vertices),'bones':len(ar.bones),'unweighted':len(unweighted),'animations':[t.name for t in rig.animation_data.nla_tracks],'export':'assets/models/actors/geo_researcher.glb'}
