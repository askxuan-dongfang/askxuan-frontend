import { mkdir, writeFile, readFile, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';
import { createHash } from 'node:crypto';

// Original, deterministic preview geometry authored for AskXuan. Coordinates
// are in nominal diameters: X is the cord axis, Y is up, Z points out of the
// bracelet. This is a schematic asset, not a scan of a merchant's SKU.
const root = fileURLToPath(new URL('./DiyMaterials/', import.meta.url));
await mkdir(root, { recursive: true });
const round = n => Math.round(n * 1e6) / 1e6;
const sphere = (x, y, z, rx, ry = rx, rz = rx) => (Math.hypot(x / rx, y / ry, z / rz) - 1) * Math.min(rx, ry, rz);
const tubeX = (x, y, z, half, radius) => Math.max(Math.abs(x) - half, Math.hypot(y, z) - radius);
const tubeZ = (x, y, z, from, to, radius) => Math.max(from - z, z - to, Math.hypot(x, y) - radius);
const smoothUnion = (a,b,k=.045) => Math.min(a,b)-Math.max(k-Math.abs(a-b),0)**2/(4*k);
const threeWay = (x, y, z) => {
  const outer = smoothUnion(smoothUnion(sphere(x, y, z, .46, .39, .43), tubeX(x, y, z, .5, .16)), tubeZ(x, y, z, 0, .65, .16));
  const bore = Math.min(Math.hypot(y, z) - .085, tubeZ(x, y, z, -.03, 1, .085));
  return Math.max(outer, -bore);
};
const motherBead = (x, y, z) => {
  const body = sphere(x, y, z, .5, .43, .47);
  const neck = tubeZ(x, y, z, .32, .86, .13);
  const bore = Math.min(Math.hypot(y, z) - .085, tubeZ(x, y, z, -.03, 1.1, .085));
  return Math.max(smoothUnion(body, neck), -bore);
};

function mesher(field, min, max, step = 1 / 22) {
  const positions = [], normals = [], uv = [], indices = [], map = new Map();
  const gradient = ([x, y, z]) => {
    const e = .0001, v = [field(x + e, y, z) - field(x - e, y, z), field(x, y + e, z) - field(x, y - e, z), field(x, y, z + e) - field(x, y, z - e)];
    const d = Math.hypot(...v) || 1; return v.map(n => n / d);
  };
  const vertex = p => {
    const values = p.map(round), key = values.join(',');
    if (map.has(key)) return map.get(key);
    const index = positions.length / 3; map.set(key, index); positions.push(...values);
    normals.push(...gradient(p).map(round));
    uv.push(round(Math.atan2(p[2], p[1]) / (2 * Math.PI) + .5), round(p[0] + .5));
    return index;
  };
  const triangle = (a, b, c) => {
    const u = b.map((n, i) => n - a[i]), v = c.map((n, i) => n - a[i]);
    const cross = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]];
    if (Math.hypot(...cross) < 1e-10) return;
    const normal = gradient(a.map((n, i) => (n + b[i] + c[i]) / 3));
    if (cross.reduce((n, v, i) => n + v * normal[i], 0) < 0) [b, c] = [c, b];
    indices.push(vertex(a), vertex(b), vertex(c));
  };
  const offsets = [[0,0,0],[1,0,0],[1,1,0],[0,1,0],[0,0,1],[1,0,1],[1,1,1],[0,1,1]];
  const tetrahedra = [[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]];
  const counts = min.map((n, i) => Math.ceil((max[i] - n) / step));
  for (let x = 0; x < counts[0]; x++) for (let y = 0; y < counts[1]; y++) for (let z = 0; z < counts[2]; z++) {
    const p = offsets.map(o => [min[0] + (x + o[0]) * step, min[1] + (y + o[1]) * step, min[2] + (z + o[2]) * step]);
    const d = p.map(p => field(...p));
    if (d.every(v => v >= 0) || d.every(v => v < 0)) continue;
    for (const tetra of tetrahedra) {
      const inside = tetra.filter(i => d[i] < 0), outside = tetra.filter(i => d[i] >= 0);
      if (!inside.length || !outside.length) continue;
      const intersection = (a, b) => p[a].map((v, i) => v + (p[b][i] - v) * d[a] / (d[a] - d[b]));
      if (inside.length === 1) triangle(...outside.map(i => intersection(inside[0], i)));
      else if (inside.length === 3) triangle(...inside.map(i => intersection(outside[0], i)));
      else {
        const [a,b,c,d] = [intersection(inside[0],outside[0]), intersection(inside[0],outside[1]), intersection(inside[1],outside[0]), intersection(inside[1],outside[1])];
        triangle(a,b,c); triangle(b,d,c);
      }
    }
  }
  return { positions, normals, uv, indices };
}

// Low-poly tubes/turned profiles retain actual empty centers. Pendants are laid
// outward on the surface, attached at the origin rather than threaded through
// their decorative body. The same mesh bytes are loaded by Web and SceneKit.
function builder() {
  const positions = [], normals = [], uv = [], indices = [];
  function surface(rows, columns, point) {
    const base = positions.length / 3;
    for (let i = 0; i <= rows; i++) for (let j = 0; j <= columns; j++) {
      const u = i / rows, v = j / columns, p = point(u,v), e = .0001;
      const a = point(u + e,v).map((n,k) => n - p[k]), b = point(u,v + e).map((n,k) => n - p[k]);
      const n = [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]], l = Math.hypot(...n) || 1;
      positions.push(...p.map(round)); normals.push(...n.map(x => round(x / l))); uv.push(round(u),round(v));
      if (i < rows && j < columns) { const a = base + i * (columns+1) + j, b = a + columns + 1; indices.push(a,b,a+1,b,b+1,a+1); }
    }
  }
  function tube(path, radius, segments = 32, sides = 8) {
    surface(segments, sides, (u,v) => {
      const p = path(u), next = path(u+.0001), t = next.map((n,i) => n-p[i]), len = Math.hypot(...t) || 1;
      const tangent = t.map(n=>n/len), helper = Math.abs(tangent[1]) < .9 ? [0,1,0] : [1,0,0];
      const a = [tangent[1]*helper[2]-tangent[2]*helper[1],tangent[2]*helper[0]-tangent[0]*helper[2],tangent[0]*helper[1]-tangent[1]*helper[0]], al = Math.hypot(...a);
      const n = a.map(x=>x/al), b = [tangent[1]*n[2]-tangent[2]*n[1],tangent[2]*n[0]-tangent[0]*n[2],tangent[0]*n[1]-tangent[1]*n[0]];
      return p.map((x,i)=>x+radius*(Math.cos(v*2*Math.PI)*n[i]-Math.sin(v*2*Math.PI)*b[i]));
    });
  }
  function ellipsoid(center, scale) { surface(24,12,(u,v)=>{const phi=u*2*Math.PI,theta=.001+v*(Math.PI-.002);return [center[0]+scale[0]*Math.cos(phi)*Math.sin(theta),center[1]+scale[1]*Math.cos(theta),center[2]+scale[2]*Math.sin(phi)*Math.sin(theta)];}); }
  function bail() { tube(t=>[0,.105*Math.sin(t*2*Math.PI),.105*Math.cos(t*2*Math.PI)],.04,24,8); }
  return { tube, ellipsoid, bail, mesh:()=>({positions,normals,uv,indices}) };
}
function pendant(kind) {
  const b = builder(); b.bail();
  if (kind === 'peace') {
    b.tube(t=>[.35*Math.sin(t*2*Math.PI),-.02,.55+.35*Math.cos(t*2*Math.PI)],.135,48,12);
  } else if (kind === 'gourd') {
    b.ellipsoid([0,-.015,.31],[.2,.14,.2]); b.ellipsoid([0,-.015,.7],[.32,.19,.3]);
    b.tube(t=>[0,-.015,.1+t*.68],.08,8,8);
  } else if (kind === 'woodfish') {
    b.ellipsoid([0,0,.58],[.42,.2,.38]);
    b.tube(t=>[.3*Math.cos(t*2*Math.PI),.17,.57+.18*Math.sin(t*2*Math.PI)],.032,24,6);
    b.tube(t=>[-.18+t*.36,.2,.55+.04*Math.sin(t*Math.PI)],.024,12,6);
  } else if (kind === 'generic') {
    b.ellipsoid([0,-.01,.58],[.33,.13,.42]);
    b.tube(t=>[0,0,.1+t*.22],.045,10,8);
  } else {
    // Open filigree lotus with six independent petal loops and a central ring.
    for (let petal=0;petal<6;petal++) { const a=petal*Math.PI/3; b.tube(t=>{const phi=t*2*Math.PI,r=.09+.3*(1-Math.cos(phi))/2,side=.095*Math.sin(phi);return [r*Math.cos(a)-side*Math.sin(a),-.01+.035*Math.sin(phi),.56+r*Math.sin(a)+side*Math.cos(a)];},.026,24,6); }
    b.tube(t=>[.1*Math.sin(t*2*Math.PI),.015,.56+.1*Math.cos(t*2*Math.PI)],.035,24,8);
    b.tube(t=>[0,0,.1+t*.18],.035,8,8);
  }
  return b.mesh();
}
function tassel(knot = false) {
  const b=builder(); b.bail();
  const offset = knot ? .62 : 0;
  if (knot) {
    // Two interlaced closed cord loops, separated in depth at their crossings.
    for (const turn of [0, Math.PI / 2]) b.tube(t => {
      const a = t * Math.PI * 2, x = .32 * Math.sin(a), z = .24 * Math.sin(2 * a);
      return [x * Math.cos(turn) - z * Math.sin(turn), .055 * Math.cos(2 * a + turn), .46 + x * Math.sin(turn) + z * Math.cos(turn)];
    }, .045, 96, 8);
    b.tube(t => [0, 0, .1 + t * .73], .035, 20, 8);
  }
  for(let i=0;i<5;i++) b.tube(t=>[.115*Math.sin(t*2*Math.PI),.075*Math.cos(t*2*Math.PI),.2+offset+i*.022],.022,24,6);
  for(let i=0;i<15;i++) {const spread=(i-7)/7; b.tube(t=>[spread*(.07+.19*t)+.012*Math.sin(t*Math.PI*2+i),-.015+.035*Math.sin(i*2.4)*(1-t),.29+offset+t*(.68+.06*Math.cos(i))],.012,14,5);}
  return b.mesh();
}
function motherMesh() {
  const base=mesher(motherBead,[-.57,-.5,-.54],[.57,.5,.94]),collars=builder();
  for(const [z,r] of [[.5,.19],[.66,.155],[.8,.12]]) collars.tube(t=>[r*Math.cos(t*2*Math.PI),r*Math.sin(t*2*Math.PI),z],.035,36,8);
  const extra=collars.mesh(),offset=base.positions.length/3;
  return {positions:[...base.positions,...extra.positions],normals:[...base.normals,...extra.normals],uv:[...base.uv,...extra.uv],indices:[...base.indices,...extra.indices.map(i=>i+offset)]};
}

function thumbnail(mesh, size=160) {
  const unit = v => { const length=Math.hypot(...v); return v.map(n=>n/length); };
  const dot = (a,b) => a.reduce((sum,n,i)=>sum+n*b[i],0);
  const eye=unit([.3,.75,.6]),right=unit([eye[2],0,-eye[0]]),down=[right[1]*eye[2]-right[2]*eye[1],right[2]*eye[0]-right[0]*eye[2],right[0]*eye[1]-right[1]*eye[0]];
  const projected=[];
  for(let i=0;i<mesh.positions.length;i+=3) { const p=mesh.positions.slice(i,i+3);projected.push([dot(p,right),dot(p,down),dot(p,eye)]); }
  const xs=projected.map(p=>p[0]),ys=projected.map(p=>p[1]),minX=Math.min(...xs),maxX=Math.max(...xs),minY=Math.min(...ys),maxY=Math.max(...ys);
  const scale=(size-16)/Math.max(maxX-minX,maxY-minY),cx=(minX+maxX)/2,cy=(minY+maxY)/2;
  const p=projected.map(v=>[(v[0]-cx)*scale+size/2,(v[1]-cy)*scale+size/2,v[2]]),rgba=Buffer.alloc(size*size*4),depth=new Float64Array(size*size).fill(-Infinity),light=unit([-.4,.85,-.35]);
  for(let i=0;i<mesh.indices.length;i+=3) {
    const ids=mesh.indices.slice(i,i+3),[a,b,c]=ids.map(i=>p[i]),den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1]);
    if(Math.abs(den)<.00001)continue;
    const normal=ids.map(i=>mesh.normals.slice(i*3,i*3+3));
    for(let y=Math.max(0,Math.floor(Math.min(a[1],b[1],c[1])));y<=Math.min(size-1,Math.ceil(Math.max(a[1],b[1],c[1])));y++)for(let x=Math.max(0,Math.floor(Math.min(a[0],b[0],c[0])));x<=Math.min(size-1,Math.ceil(Math.max(a[0],b[0],c[0])));x++) {
      const u=((b[1]-c[1])*(x+.5-c[0])+(c[0]-b[0])*(y+.5-c[1]))/den,v=((c[1]-a[1])*(x+.5-c[0])+(a[0]-c[0])*(y+.5-c[1]))/den,w=1-u-v;
      if(u<0||v<0||w<0)continue;
      const z=u*a[2]+v*b[2]+w*c[2],offset=y*size+x;if(z<=depth[offset])continue;depth[offset]=z;
      const n=unit([0,1,2].map(k=>normal[0][k]*u+normal[1][k]*v+normal[2][k]*w)),value=Math.round(255*(.38+.62*Math.max(0,dot(n,light))));
      rgba[offset*4]=rgba[offset*4+1]=rgba[offset*4+2]=value;rgba[offset*4+3]=255;
    }
  }
  const crc = data => {let crc=0xffffffff;for(const byte of data){crc^=byte;for(let i=0;i<8;i++)crc=(crc>>>1)^((crc&1)?0xedb88320:0);}return(crc^0xffffffff)>>>0;};
  const chunk=(name,data)=>{const type=Buffer.from(name),size=Buffer.alloc(4),checksum=Buffer.alloc(4);size.writeUInt32BE(data.length);checksum.writeUInt32BE(crc(Buffer.concat([type,data])));return Buffer.concat([size,type,data,checksum]);};
  const header=Buffer.alloc(13);header.writeUInt32BE(size,0);header.writeUInt32BE(size,4);header[8]=8;header[9]=6;
  const rows=Buffer.concat(Array.from({length:size},(_,i)=>Buffer.concat([Buffer.from([0]),rgba.subarray(i*size*4,(i+1)*size*4)])));
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),chunk('IDAT',deflateSync(rows)),chunk('IEND',Buffer.alloc(0))]);
}

const models = {
  three_way: { mesh: mesher(threeWay,[-.57,-.46,-.5],[.57,.46,.73]), pitchRatio:1, radialRatio:.86, minY:-.39, maxY:.39, minZ:-.43, maxZ:.65 },
  buddha_head: { mesh: motherMesh(), pitchRatio:1, radialRatio:.94, minY:-.43, maxY:.43, minZ:-.47, maxZ:.87 },
  pendant_lotus: {mesh:pendant('lotus'),pitchRatio:.1,radialRatio:.12,minY:-.145,maxY:.145,minZ:-.145,maxZ:.98},
  pendant_gourd: {mesh:pendant('gourd'),pitchRatio:.1,radialRatio:.12,minY:-.205,maxY:.175,minZ:-.145,maxZ:1},
  pendant_peace: {mesh:pendant('peace'),pitchRatio:.1,radialRatio:.12,minY:-.155,maxY:.145,minZ:-.145,maxZ:1.035},
  pendant_woodfish: {mesh:pendant('woodfish'),pitchRatio:.1,radialRatio:.12,minY:-.2,maxY:.224,minZ:-.145,maxZ:.96},
  pendant_generic: {mesh:pendant('generic'),pitchRatio:.1,radialRatio:.12,minY:-.145,maxY:.145,minZ:-.145,maxZ:1},
  tassel: {mesh:tassel(),pitchRatio:.1,radialRatio:.12,minY:-.145,maxY:.145,minZ:-.145,maxZ:1.05},
  tassel_knot: {mesh:tassel(true),pitchRatio:.1,radialRatio:.12,minY:-.145,maxY:.145,minZ:-.145,maxZ:1.67},
};
const catalog = {version:1,units:'nominal-diameter',axes:{cord:'x',up:'y',outward:'z'},byMaterialId:{'11':'pendant_lotus','41':'pendant_gourd','42':'pendant_peace','43':'pendant_woodfish'},nameVariants:[{matches:['莲花','蓮花'],kind:'pendant_lotus'},{matches:['葫芦','葫蘆'],kind:'pendant_gourd'},{matches:['平安扣'],kind:'pendant_peace'},{matches:['木鱼','木魚'],kind:'pendant_woodfish'},{matches:['中国结','中國結'],kind:'tassel_knot'}],models:{}};
for (const [name,{mesh,...metadata}] of Object.entries(models)) {
  const file=`geometry-${name}.json`; await writeFile(root+file,JSON.stringify({version:1,...mesh})+'\n');
  const image=`geometry-${name}.png`;await writeFile(root+image,thumbnail(mesh));
  const xs=mesh.positions.filter((_,index)=>index%3===0);
  catalog.models[name]={...metadata,minX:Math.min(...xs),maxX:Math.max(...xs),spacingRatio:name.startsWith('pendant')?.9:name.startsWith('tassel')?.56:1,file,thumbnail:image,...(name.startsWith('pendant')||name.startsWith('tassel')?{connectorRatio:.12}:{}),anchors:{...(name.startsWith('pendant')||name.startsWith('tassel')?{mount:[0,0,metadata.minZ]}:{}),left:[-metadata.pitchRatio/2,0,0],right:[metadata.pitchRatio/2,0,0],...(name==='three_way'||name==='buddha_head'?{outward:[0,0,metadata.maxZ]}:{})}};
  console.log(`${name}: ${mesh.positions.length/3} vertices, ${mesh.indices.length/3} triangles`);
}
await writeFile(root+'geometry-catalog.json',JSON.stringify(catalog,null,2)+'\n');
const sources=JSON.parse(await readFile(root+'sources.json','utf8'));
const authored=sources.find(item=>item.id==='askxuan-accessory-models-v1');
if(authored) {
  authored.files=await Promise.all((await readdir(root)).filter(name=>name.startsWith('geometry-')).sort().map(async path=>({path,sha256:createHash('sha256').update(await readFile(root+path)).digest('hex')})));
  await writeFile(root+'sources.json',JSON.stringify(sources,null,2)+'\n');
}
