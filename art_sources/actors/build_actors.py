"""TRIP original low-poly expedition actor + six taiga species; Blender MCP.
Metres. Facing Blender -Y (= Godot +Z). Skinned parts, explicit NLA loops.
"""
import bpy, math, os
from pathlib import Path
source=Path('/Users/shaman/Desktop/Projects/Godot/TRIP/art_sources/menu_camp/build_menu.py').read_text()
exec(source.split('variants=')[0].replace('TRIP Menu • Cedar clearing','TRIP • Actors'))
skin=material('Weathered skin',(.46,.27,.17));coat=material('Waxed field jacket',(.19,.25,.15));cloth=material('Charcoal trousers',(.075,.085,.08));hair=material('Dark hair and beard',(.075,.045,.025));eye=material('Eyes',(.018,.02,.014),.3);trim=material('Ochre stitching',(.48,.32,.10));boot=material('Boot leather',(.09,.047,.024))
fur=material('Taiga brown fur',(.22,.12,.065));pale=material('Throat and muzzle',(.53,.40,.23));wolf=material('Wolf grey guard coat',(.25,.27,.24));black=material('Claws and nose',(.025,.025,.019));antler=material('Antler bone',(.55,.43,.27));feather=material('Eagle umber feathers',(.115,.075,.045))
def ell(m,c,s,mat,n=12,rings=8):
    c=Vector(c)
    for k in range(rings):
        a=-math.pi/2+k*math.pi/rings;b=a+math.pi/rings
        for j in range(n):
            vs=[]
            for h,t in [(a,j),(a,j+1),(b,j+1),(b,j)]:
                q=t*math.tau/n;vs.append(c+Vector((s[0]*math.cos(h)*math.cos(q),s[1]*math.cos(h)*math.sin(q),s[2]*math.sin(h))))
            m.face(vs,mat)
def newrig(name,bones):
    ar=bpy.data.armatures.new(name);ob=bpy.data.objects.new(name,ar);scene.collection.objects.link(ob)
    with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
        bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
        bpy.ops.object.mode_set(mode='EDIT')
        for name,h,t,parent in bones:
            b=ar.edit_bones.new(name);b.head=h;b.tail=t
            if parent:b.parent=ar.edit_bones[parent]
        bpy.ops.object.mode_set(mode='OBJECT')
    return ob
def attach(m,rig,bone):
    ob=m.finish();vg=ob.vertex_groups.new(name=bone);vg.add(list(range(len(ob.data.vertices))),1,'REPLACE')
    mod=ob.modifiers.new('Deform','ARMATURE');mod.object=rig;ob.parent=rig;return ob
def clips(rig,legs,arms=(),prefix=''):
    for state,amp,length in [('Idle',.035,60),('Walk',.5,36),('Run',.85,24),('Jump',.32,32),('Working',.28,44),('Death',.1,48)]:
        rig.animation_data_create();rig.animation_data.action=None
        for f in range(1,length+2,3):
            phase=(f-1)/length*math.tau
            for i,b in enumerate(legs+list(arms)):
                pb=rig.pose.bones[b];pb.rotation_mode='XYZ'
                pb.rotation_euler=(math.sin(phase+(i%2)*math.pi)*amp,0,0)
                if state=='Working' and b in arms:pb.rotation_euler.x=-.5+math.sin(phase)*.25
                pb.keyframe_insert('rotation_euler',frame=f)
        # Exact matching endpoints prevents loop seam flicks.
        for b in legs+list(arms):
            pb=rig.pose.bones[b];pb.rotation_euler=(0,0,0);pb.keyframe_insert('rotation_euler',frame=length+1)
        action=rig.animation_data.action;action.name=prefix+state
        track=rig.animation_data.nla_tracks.new();track.name=prefix+state
        track.strips.new(prefix+state,1,action);rig.animation_data.action=None
    for pb in rig.pose.bones:pb.rotation_euler=(0,0,0)
def export(rig,key):
    out=ROOT+'/assets/models/actors';os.makedirs(out,exist_ok=True)
    with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
        bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
        for ob in rig.children:ob.select_set(True)
        bpy.ops.export_scene.gltf(filepath=out+'/'+key+'.glb',export_format='GLB',use_selection=True,use_active_scene=True,export_animation_mode='NLA_TRACKS')
bones=[('Root',(0,0,0),(0,0,.2),None),('Hips',(0,0,.89),(0,0,1.05),'Root'),('Spine',(0,0,1.05),(0,0,1.46),'Hips'),('Head',(0,0,1.47),(0,0,1.78),'Spine')]
for side,x in [('L',-.16),('R',.16)]:
    bones += [(side+'Thigh',(x,0,.91),(x,0,.5),'Hips'),(side+'Shin',(x,0,.5),(x,-.02,.12),side+'Thigh'),(side+'Arm',(x*1.65,0,1.43),(x*2.45,0,1.15),'Spine'),(side+'Forearm',(x*2.45,0,1.15),(x*2.7,-.06,.94),side+'Arm')]
rig=newrig('ExpeditionResearcher',bones)
m=Mesh('Jacket • tailored torso');ell(m,(0,0,1.22),(.255,.145,.29),coat)
m.tube([(0,-.145,1.02),(0,-.156,1.45)],[.008,.008],trim,5)
for x in [-.13,.13]:ell(m,(x,-.145,1.25),(.07,.018,.075),coat,8,4)
ell(m,(0,.19,1.23),(.20,.11,.245),bark)
for x in [-.18,.18]:m.tube([(x,.05,1.46),(x,-.12,1.36),(x,-.14,1.13)],[.025]*3,boot,6)
m.tube([(-.21,.18,1.5),(.21,.18,1.5)],[.082,.082],canvas if 'canvas' in globals() else coat,12)
attach(m,rig,'Spine')
m=Mesh('Trousers • hip and belt');ell(m,(0,0,.92),(.22,.14,.15),cloth)
m.tube([(-.20,0,1.03),(.20,0,1.03)],[.055,.055],boot,6);attach(m,rig,'Hips')
m=Mesh('Head • cheekbones nose ears hair beard');ell(m,(0,-.01,1.65),(.115,.10,.16),skin)
ell(m,(0,.008,1.755),(.12,.10,.085),hair)
ell(m,(0,-.071,1.57),(.085,.046,.07),hair)
ell(m,(0,-.11,1.651),(.027,.041,.04),skin,8,5)
for x in [-.118,.118]:ell(m,(x,-.008,1.65),(.024,.022,.045),skin,8,5)
for x in [-.046,.046]:
    ell(m,(x,-.095,1.68),(.02,.01,.012),eye,8,4)
    m.tube([(x-.022,-.097,1.704),(x+.022,-.097,1.7)],[.008,.008],hair,5)
attach(m,rig,'Head')
for side,x in [('L',-.16),('R',.16)]:
    m=Mesh(side+' trouser thigh');m.tube([(x,0,.93),(x,0,.70),(x,0,.48)],[.105,.10,.075],cloth,12);attach(m,rig,side+'Thigh')
    m=Mesh(side+' boot and gaiter');m.tube([(x,0,.5),(x,0,.25),(x,-.01,.10)],[.077,.083,.074],boot,12)
    ell(m,(x,-.07,.09),(.09,.16,.08),boot)
    for z in [.16,.21,.26]:m.tube([(x-.045,-.078,z),(x+.045,-.078,z+.02)],[.006,.006],trim,4)
    attach(m,rig,side+'Shin')
    m=Mesh(side+' upper sleeve');m.tube([(x*1.5,0,1.45),(x*2.45,0,1.14)],[.10,.075],coat,12);attach(m,rig,side+'Arm')
    m=Mesh(side+' cuff and glove');m.tube([(x*2.45,0,1.16),(x*2.7,-.06,.98)],[.075,.055],coat,12)
    ell(m,(x*2.7,-.06,.935),(.06,.045,.08),boot)
    for j in range(4):m.tube([(x*2.7-.038+j*.024,-.075,.92),(x*2.7-.038+j*.024,-.087,.86)],[.012,.01],boot,6)
    attach(m,rig,side+'Forearm')
clips(rig,['LThigh','RThigh','RShin','LShin'],['RArm','LArm'],'Human Armature|');export(rig,'researcher')
species={'maral':(1.15,.65,.28,fur),'musk_deer':(.72,.44,.19,fur),'wolf':(.73,.64,.23,wolf),'bear':(.97,.78,.42,fur),'sable':(.24,.28,.12,fur),'eagle':(.42,.30,.16,feather)}
for key,(h,length,width,mat) in species.items():
    b=[('Root',(0,0,0),(0,0,.15),None),('Body',(0,0,h*.6),(0,0,h),'Root'),('Head',(0,-length*.73,h),(0,-length,h+.24),'Body')]
    for j,(x,y) in enumerate([(-width,-length*.55),(width,-length*.55),(-width,length*.55),(width,length*.55)]):b.append(('Leg'+str(j),(x,y,h*.85),(x,y,.04),'Body'))
    animal=newrig('Taiga_'+key,b)
    m=Mesh(key+' • torso and tail');ell(m,(0,0,h), (width,length,h*.3),mat)
    if key=='bear':ell(m,(0,-length*.36,h*1.1),(width*.95,.38,.35),mat)
    if key in ['wolf','sable']:m.tube([(0,length*.85,h),(0,length*1.25,h*.85),(0,length*1.8,h*.45)],[width*.48,width*.65,.035],mat,9)
    if key=='eagle':
        m.tube([(0,.2,.43),(0,.55,.40)],[.1,.025],feather,6)
    attach(m,animal,'Body')
    m=Mesh(key+' • muzzle ears and eyes');ell(m,(0,-length*.93,h+.16),(width*.68,width*.8,width*.85),mat)
    ell(m,(0,-length-width*.52,h+.09),(width*.44,width*.65,width*.4),pale)
    if key=='eagle':
        m.tube([(0,-length-width*.7,h+.13),(0,-length-width*1.5,h+.07)],[.035,.002],antler,8)
    else:
        ell(m,(0,-length-width*1.06,h+.09),(width*.24,.025,width*.18),black)
    for x in [-width*.52,width*.52]:
        ell(m,(x,-length*.98,h+.21),(.018,.025,.02),black,8,4)
        if key!='eagle':ell(m,(x,-length*.74,h+.32),(.05,.035,.10 if key!='bear' else .055),mat,8,5)
    if key=='maral':
        for sign in [-1,1]:
            m.tube([(sign*.1,-length*.75,h+.32),(sign*.24,-length*.6,h+.68),(sign*.32,-length*.42,h+.94)],[.035,.025,.005],antler,7)
            for j in range(3):m.tube([(sign*(.15+j*.06),-length*.65,h+.45+j*.13),(sign*(.32+j*.07),-length*.95,h+.66+j*.14)],[.017,.002],antler,6)
    attach(m,animal,'Head')
    for j,(x,y) in enumerate([(-width,-length*.55),(width,-length*.55),(-width,length*.55),(width,length*.55)]):
        if key=='eagle' and j<2:
            m=Mesh('Eagle wing '+str(j));sign=-1 if j==0 else 1
            for k in range(9):m.leaf((sign*.1,.02,.44),(sign,.2+k*.06,-.12),.9-k*.025,.10,feather)
            attach(m,animal,'Leg'+str(j));continue
        m=Mesh(key+' leg '+str(j));m.tube([(x,y,h*.9),(x,y+.05,h*.42),(x,y,.06)],[width*.3,width*.18,width*.16],mat,8)
        ell(m,(x,y-.035,.05),(width*.23,width*.32,.05),black,8,4);attach(m,animal,'Leg'+str(j))
    clips(animal,['Leg0','Leg3','Leg1','Leg2']);export(animal,key)
# Store editable rig/mesh source; no exporter transforms are applied destructively.
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/art_sources/actors/taiga_actors.blend')
result={'exported':['researcher']+list(species),'rigged':True}
