
const result={changed:[],added:[],fillOverrides:[]};
const sourceIds={lilac:'83:2',blush:'83:3',spark:'83:4',ring:'83:6',warm:'74:6',wave:'83:8',moon:'74:4',drop:'74:2',leaves:'77:3',mint:'77:2'};
const sources={};for(const [k,id]of Object.entries(sourceIds))sources[k]=await figma.getNodeByIdAsync(id);
function rgb(h){return {r:parseInt(h.slice(0,2),16)/255,g:parseInt(h.slice(2,4),16)/255,b:parseInt(h.slice(4,6),16)/255};}
function cloneInto(layer,kind,x,y,width,opacity,color){
 const n=sources[kind].clone();layer.appendChild(n);n.name='decoration/'+kind;
 n.rescale(width/n.width);n.x=x;n.y=y;if(opacity!==undefined)n.opacity=opacity;
 if(color){for(const d of [n,...('findAll'in n?n.findAll():[])]){if('strokes'in d&&d.strokes.length)d.strokes=d.strokes.map(p=>p.type==='SOLID'?{...p,color:rgb(color)}:p);}}
 result.added.push(n.id);return n;
}
function decorate(card,variant){
 if(card.children.some(n=>n.name==='decoration/me-family'))return;
 const w=card.width,h=card.height;const oldClip=card.clipsContent;
 if(variant==='utility'&&card.name==='card/settings'){
 for(const child of card.children.filter(n=>n.type==='INSTANCE')){
 result.fillOverrides.push({id:child.id,fills:child.fills});child.fills=[];
 }
 }
 const layer=figma.createFrame();layer.name='decoration/me-family';layer.fills=[];layer.clipsContent=true;layer.resize(w,h);
 card.appendChild(layer);layer.layoutPositioning='ABSOLUTE';layer.x=0;layer.y=0;layer.constraints={horizontal:'STRETCH',vertical:'STRETCH'};card.insertChild(0,layer);card.clipsContent=true;
 result.added.push(layer.id);
 if(variant==='ai'){
  cloneInto(layer,'lilac',w-106,-30,140,.24);
  cloneInto(layer,'blush',-38,h-49,150,.30);
  cloneInto(layer,'spark',w-49,78,18,.48);
 }else if(variant==='sleep'){
  cloneInto(layer,'warm',w-64,h-58,90,.70);
  cloneInto(layer,'moon',w-34,17,38,.72);
 }else if(variant==='wet'){
  cloneInto(layer,'warm',w-55,h-51,82,.56);
  cloneInto(layer,'drop',w-38,17,34,.64);
 }else if(variant==='stool'){
  cloneInto(layer,'blush',w-74,h-49,108,.32);
  cloneInto(layer,'wave',w-129,h-46,160,.55);
 }else if(variant==='feeding'){
  cloneInto(layer,'blush',w-83,-24,125,.30);
  cloneInto(layer,'drop',w-113,5,38,.62);
  cloneInto(layer,'wave',w-213,h-44,210,.40);
 }else if(variant==='measurement'){
  cloneInto(layer,'warm',w-40,h-48,76,.28);
  cloneInto(layer,'ring',w-46,h-50,64,.34,'E5D5C1');
 }else if(variant==='chart'||variant==='calendar'){
  layer.resize(w,variant==='chart'?76:78);
  cloneInto(layer,'mint',w-69,-47,118,.25);
  cloneInto(layer,'ring',w-56,-25,80,.36,'C9DED5');
 }else if(variant==='appointment'){
  cloneInto(layer,'mint',w-70,-23,116,.28);
  cloneInto(layer,'leaves',w-77,h-81,65,.30,'B9D4C7');
 }else if(variant==='task'){
  cloneInto(layer,'mint',w-72,-23,116,.38);
  cloneInto(layer,'ring',w-80,h-73,96,.55,'FFFFFF');
 }else if(variant==='personal'||variant==='account'){
  cloneInto(layer,'blush',w-94,-21,138,.34);
  cloneInto(layer,'wave',w-198,h-55,218,.60);
 }else if(variant==='plan'){
  cloneInto(layer,'warm',w-68,h-60,100,.52);
  cloneInto(layer,'ring',w-57,h-67,94,.56);
 }else if(variant==='utility'){
  cloneInto(layer,'mint',w-72,-29,112,.22);
  cloneInto(layer,'wave',w-175,h-59,200,.24,'BBD2C8');
 }else if(variant==='resource'){
 layer.resize(w,Math.min(70,h));cloneInto(layer,'mint',w-60,-30,104,.22);cloneInto(layer,'leaves',w-70,5,50,.20,'B9D4C7');
 }else if(variant==='monitor'){
  cloneInto(layer,'wave',w-168,h-52,194,.25,'BBD2C8');
 }
 layer.locked=true;
 result.changed.push({id:card.id,name:card.name,variant,layer:layer.id,oldClip,w,h});
}
const targets=[]; // Populate from plan.json targets; mutation is idempotent.
for(const [id,variant]of targets){const n=await figma.getNodeByIdAsync(id);if(n&&n.type==='FRAME')decorate(n,variant);}
return result;

