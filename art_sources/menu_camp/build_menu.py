"""Run with official Blender MCP execute_blender_code; metres, Z-up.
Original TRIP geometry. No external textures or asset licensing dependencies.
Creates a separate scene; leaves existing Blender scenes untouched.
"""
import bpy, math, random, os
from mathutils import Vector
R=random.Random(7183)
ROOT='/Users/shaman/Desktop/Projects/Godot/TRIP'
scene=bpy.data.scenes.new('TRIP Menu • Cedar clearing')
bpy.context.window.scene=scene
mats=[]
def material(name,color,rough=0.9,metal=0,emission=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    if emission:
        p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
    mats.append(m);return len(mats)-1
bark=material('Cedar • warm fissured bark',(.19,.105,.052))
wood=material('Exposed heartwood',(.48,.28,.12))
pine=material('Needles • deep jade',(.045,.16,.11))
tips=material('Needles • silver sage tips',(.15,.28,.18))
larch=material('Larch • bronze needles',(.30,.32,.10))
stone=material('River granite',(.24,.28,.28))
stone2=material('Granite • pale fracture',(.38,.41,.37))
moss=material('Moss',(.16,.23,.07))
soil=material('Forest humus',(.10,.075,.043))
path=material('Trodden clay',(.23,.16,.085))
char=material('Charcoal',(.025,.021,.018))
ember=material('Ember cracks',(.8,.045,.002),emission=3)
fern=material('Fern • fronds',(.16,.30,.105))
iron=material('Forged iron',(.065,.068,.07),.6,.65)
copper=material('Weathered copper',(.34,.16,.075),.38,.7)
ceramic=material('Glazed stoneware',(.17,.28,.22),.3)
class Mesh:
    def __init__(self,name):self.name=name;self.v=[];self.f=[];self.mi=[]
    def face(self,vs,mat):
        i=len(self.v);self.v.extend(vs);self.f.append(tuple(range(i,i+len(vs))));self.mi.append(mat)
    def tube(self,points,radii,mat,n=7):
        rings=[]
        for i,p in enumerate(points):
            p=Vector(p);d=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
            d.normalize();a=d.cross(Vector((0,1,0)))
            if a.length<.01:a=d.cross(Vector((1,0,0)))
            a.normalize();b=d.cross(a)
            rings.append([p+radii[i]*(math.cos(j*math.tau/n)*a+math.sin(j*math.tau/n)*b) for j in range(n)])
        for i in range(len(rings)-1):
            for j in range(n):self.face([rings[i][j],rings[i][(j+1)%n],rings[i+1][(j+1)%n],rings[i+1][j]],mat)
        self.face(list(reversed(rings[0])),mat);self.face(rings[-1],wood if mat==bark else mat)
    def leaf(self,p,d,length,width,mat):
        p=Vector(p);d=Vector(d).normalized();side=d.cross(Vector((0,0,1))).normalized()*width
        mid=p+d*length*.5;tip=p+d*length
        self.face([p,mid+side,mid+Vector((0,0,width*.35))],mat)
        self.face([mid+side,tip,mid+Vector((0,0,width*.35))],mat)
        self.face([tip,mid-side,mid+Vector((0,0,width*.35))],mat)
        self.face([mid-side,p,mid+Vector((0,0,width*.35))],mat)
    def rock(self,p,s,mat):
        p=Vector(p);rings=[];n=7
        for z,r in [(-.38,.65),(-.05,1),(.45,.68)]:
            rings.append([p+Vector((math.cos(j*math.tau/n)*s[0]*r*R.uniform(.8,1.2),math.sin(j*math.tau/n)*s[1]*r*R.uniform(.8,1.2),z*s[2]*R.uniform(.8,1.2))) for j in range(n)])
        for k in range(2):
            for j in range(n):
                a,b,c,d=rings[k][j],rings[k][(j+1)%n],rings[k+1][(j+1)%n],rings[k+1][j]
                self.face([a,b,c],mat);self.face([a,c,d],stone2 if mat==stone and R.random()<.18 else mat)
        top=p+Vector((.07*s[0],-.1*s[1],.58*s[2]))
        for j in range(n):self.face([rings[-1][j],rings[-1][(j+1)%n],top],mat)
        self.face(list(reversed(rings[0])),mat)
    def finish(self):
        me=bpy.data.meshes.new(self.name);me.from_pydata(self.v,[],self.f);me.update()
        for m in mats:me.materials.append(m)
        for p,i in zip(me.polygons,self.mi):p.material_index=i
        ob=bpy.data.objects.new(self.name,me);scene.collection.objects.link(ob);return ob
def tree(name,h,kind):
    m=Mesh(name);lean=R.uniform(-.4,.4)
    m.tube([(0,0,0),(lean,0,h*.36),(lean*.5,.12,h*.72),(0,.2,h)],[h*.035,h*.024,h*.012,.015],bark,9)
    for j in range(6):
        a=j*math.tau/6;m.tube([(math.cos(a)*.85,math.sin(a)*.85,.02),(math.cos(a)*.35,math.sin(a)*.35,.16),(0,0,.65)],[.08,.16,.2],bark)
    for tier in range(8):
        z=h*(.23+tier*.084);length=h*(.30-tier*.029)
        for j in range(4):
            a=j*math.tau/4+tier*.77+R.uniform(-.18,.18)
            direction=Vector((math.cos(a),math.sin(a),0));base=Vector((lean*.6,0,z))
            end=base+direction*length+Vector((0,0,.18 if kind==0 else -.25))
            m.tube([base,base+direction*length*.5+Vector((0,0,-.16)),end],[.085,.043,.008],bark,5)
            for k in range(1,7):
                t=k/7;center=base.lerp(end,t)
                for sign in [-1,1]:
                    side=Vector((math.cos(a+sign*.8),math.sin(a+sign*.8),.12))
                    span=length*.43*(1-t*.65)
                    m.tube([center,center+side*span],[.018,.002],bark,4)
                    for q in range(2):
                        origin=center+side*span*q/2
                        m.leaf(origin,(math.cos(a+sign*1.0),math.sin(a+sign*1.0),.1),span*.95,.26 if kind==0 else .19,larch if kind==2 else (tips if R.random()<.3 else pine))
                    if k%2==0:
                        m.rock(center+side*span*.45,(span*.8,span*.65,.27),larch if kind==2 else pine)
    return m.finish()
variants=[tree('Cedar • spreading crown',9,0),tree('Fir • narrow crown',11,1),tree('Larch • open branches',8,2)]
for ob in variants:ob.hide_render=True;ob.hide_set(True)
def ground(x,y):return -.08+.7*math.sin(x*.14)*math.sin(y*.15)+max(0,y-6)*.07
for i,(x,y) in enumerate([(-9,-4),(-7,0),(-9,5),(-6,8),(-2,11),(3,12),(7,10),(10,5),(12,0),(-13,12),(-9,16),(-4,18),(1,21),(7,19),(12,17),(16,11),(-17,5),(-15,20),(18,20),(-20,16),(15,-4)]):
    source=variants[i%3];ob=bpy.data.objects.new('Grove %02d • '%i+source.name,source.data);scene.collection.objects.link(ob)
    ob.location=(x,y,ground(x,y));s=R.uniform(.85,1.25);ob.scale=(s,s,s);ob.rotation_euler.z=R.random()*math.tau
for ob in variants:bpy.data.objects.remove(ob,do_unlink=True)
m=Mesh('Clearing • sculpted forest floor')
for x in range(-24,24):
    for y in range(-14,28):
        pts=[(x,y,ground(x,y)),(x+1,y,ground(x+1,y)),(x+1,y+1,ground(x+1,y+1)),(x,y+1,ground(x,y+1))]
        mat=soil
        m.face([pts[0],pts[1],pts[2]],mat);m.face([pts[0],pts[2],pts[3]],mat)
m.finish()
m=Mesh('Granite • outcrops and moss caps')
for i in range(44):
    x,y=R.uniform(-15,15),R.uniform(-5,22)
    if x*x+y*y<20:continue
    s=R.uniform(.4,1.6);p=(x,y,ground(x,y)+s*.23);m.rock(p,(s,s*.75,s*.95),stone)
    if i%2==0:m.rock((x,y,p[2]+s*.42),(s*.64,s*.48,.10),moss)
m.finish()
m=Mesh('Undergrowth • feathered ferns')
for i in range(150):
    x,y=R.uniform(-13,13),R.uniform(-7,19)
    if abs(x-2*math.sin(y*.16))<2.1 or x*x+y*y<9:continue
    base=Vector((x,y,ground(x,y)));size=R.uniform(.35,.85)
    for j in range(6):
        a=j*math.tau/6;d=Vector((math.cos(a),math.sin(a),.8))
        for k in range(1,6):
            p=base+d*size*k/6
            for sign in [-1,1]:m.leaf(p,(math.cos(a+sign*.85),math.sin(a+sign*.85),.25),size*.38*(1-k/7),.06,fern)
m.finish()
m=Mesh('Deadfall • split cedar logs')
for x,y,a in [(-4,3,.4),(5,6,2.1),(-8,10,1.1)]:
    p=Vector((x,y,ground(x,y)+.23));d=Vector((math.cos(a),math.sin(a),.02))
    m.tube([p,p+d*1.3,p+d*2.7],[.25,.23,.19],bark,11)
    m.tube([p+d*.9,p+d*.9+Vector((.2,.4,.55))],[.1,.02],bark)
m.finish()
m=Mesh('Hearth • granite ring and charcoal bed')
for i in range(13):
    a=i*math.tau/13;m.rock((math.cos(a)*.87,math.sin(a)*.87,.12),(.26,.22,.32),stone)
for i in range(28):
    a=R.random()*math.tau;r=R.random()*.62;m.rock((math.cos(a)*r,math.sin(a)*r,.07),(.12,.1,.08),ember if i%4==0 else char)
for i in range(5):
    a=i*math.pi/2.5;p=Vector((math.cos(a)*-.6,math.sin(a)*-.6,.16+i*.035));d=Vector((math.cos(a),math.sin(a),.05))
    m.tube([p,p+d*.6,p+d*1.2],[.105,.14,.08],char,9)
    m.tube([p+Vector((0,0,.09)),p+d*.8+Vector((0,0,.11))],[.012,.004],ember,4)
m.finish()
m=Mesh('Hearth • cooking tripod')
for a in [0,2.1,4.2]:m.tube([(math.cos(a)*1.1,math.sin(a)*1.1,.02),(.03,0,1.9)],[.035,.028],iron)
m.tube([(0,0,1.86),(0,0,1.08)],[.012,.012],iron,5);m.finish()
m=Mesh('Hearth • hanging cauldron')
m.tube([(0,0,.49),(0,0,.58),(0,0,.84),(0,0,.94)],[.18,.30,.30,.25],iron,14)
m.tube([(-.27,0,.82),(-.20,0,1.12),(0,0,1.22),(.20,0,1.12),(.27,0,.82)],[.017]*5,iron,6)
m.finish()
m=Mesh('Field bench • cedar planks and stoneware')
for y in [-.3,0,.3]:m.tube([(-4.35,y,.86),(-2.25,y,.86)],[.16,.16],bark,4)
for x in [-4.15,-2.45]:
    for y in [-.3,.3]:m.tube([(x,y,0),(x,y,.83)],[.065,.065],bark,6)
for i in range(5):
    x=-4.1+i*.34;y=.1;h=.25+i%3*.1
    m.tube([(x,y,.98),(x,y,1.06),(x,y,1.0+h),(x,y,1.09+h)],[.09,.13,.075,.035],ceramic if i%2 else copper,12)
m.finish()
os.makedirs(ROOT+'/assets/models/menu_camp',exist_ok=True)
with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
    bpy.ops.object.select_all(action='SELECT')
    # Equipment is shared with the playable laboratory via separate GLBs.
    for ob in scene.objects:
        if ob.name.startswith(('Field bench', 'Hearth • hanging')):
            ob.select_set(False)
    bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/models/menu_camp/cedar_clearing.glb',export_format='GLB',use_selection=True,use_active_scene=True)
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/art_sources/menu_camp/cedar_clearing.blend')
result={'scene':scene.name,'objects':len(scene.objects),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in scene.objects if o.type=='MESH'),'export':'assets/models/menu_camp/cedar_clearing.glb'}
