import bpy, math, os
from pathlib import Path
source=Path('/Users/shaman/Desktop/Projects/Godot/TRIP/art_sources/menu_camp/build_menu.py').read_text()
exec(source.split('variants=')[0].replace('TRIP Menu • Cedar clearing','TRIP • Ordinary taiga kit'))
OUT=ROOT+'/assets/models/taiga';os.makedirs(OUT,exist_ok=True)
objects=[]
def save(ob,key,reduce=False):
    with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
        bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
        if reduce:
            mod=ob.modifiers.new('Runtime silhouette budget','DECIMATE');mod.ratio=.18;bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.ops.export_scene.gltf(filepath=OUT+'/'+key+'.glb',export_format='GLB',use_selection=True,use_active_scene=True)
    objects.append(ob)
for key,h,kind in [('cedar',8,0),('fir',10,1),('young_fir',3.5,1),('wind_cedar',6,0)]:save(tree(key,h,kind),key,True)
for i,key in enumerate(['granite_round','granite_split','granite_moss']):
    m=Mesh(key)
    m.rock((0,0,.45),(1.2,.85,1.3),stone)
    if i==1:m.rock((.65,.22,.3),(.65,.6,.9),stone2)
    if i==2:m.rock((-.13,.05,1.0),(.72,.55,.14),moss)
    save(m.finish(),key)
m=Mesh('Dead cedar • broken limb');m.tube([(-1.6,0,.16),(0,.06,.22),(1.3,0,.12)],[.22,.25,.14],bark,9)
m.tube([(-.3,0,.2),(-.2,.3,.7),(.1,.4,.9)],[.12,.055,.012],bark,7);save(m.finish(),'deadfall')
m=Mesh('Rotten stump');m.tube([(0,0,0),(.04,0,.5),(0,0,.76)],[.32,.25,.18],bark,9);save(m.finish(),'stump')
for key,color in [('fern',fern),('berry_shrub',tips),('sedge',moss)]:
    m=Mesh(key)
    for j in range(7):
        a=j*math.tau/7;d=Vector((math.cos(a),math.sin(a),.75))
        if key=='berry_shrub':m.tube([(0,0,0),d*.65],[.025,.006],bark,5)
        for k in range(1,5):
            p=d*k*.12
            for sign in [-1,1]:m.leaf(p,(math.cos(a+sign*.8),math.sin(a+sign*.8),.2),.24-k*.028,.06,color)
    save(m.finish(),key)
m=Mesh('Mooncap cluster')
for x,y,s in [(0,0,1),(.15,0,.7),(-.1,.12,.6)]:
    m.tube([(x,y,0),(x+.025,y,.20*s)],[.025*s,.02*s],wood,7)
    m.rock((x+.025,y,.23*s),(.12*s,.12*s,.09*s),stone2)
save(m.finish(),'fungi')
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/art_sources/taiga/ordinary_taiga.blend')
result={'models':len(objects),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects)}
