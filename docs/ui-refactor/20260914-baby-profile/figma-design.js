
const C={bg:'#FBF8F4',surface:'#FFFEFC',ink:'#2B2826',secondary:'#776E69',border:'#E9E1DC',rose:'#B54F78',mint:'#E7F3EF',teal:'#46717C',amber:'#F8EED9',neutral:'#F0E9E4'};
const rgb=h=>({r:parseInt(h.slice(1,3),16)/255,g:parseInt(h.slice(3,5),16)/255,b:parseInt(h.slice(5,7),16)/255});
const fill=h=>[{type:'SOLID',color:rgb(h)}];
await figma.loadFontAsync({family:'Noto Sans SC',style:'Regular'});
await figma.loadFontAsync({family:'Noto Sans SC',style:'Bold'});
function box(parent,name,w,h,color=C.surface,r=0){const f=figma.createFrame();f.name=name;f.resize(w,h);f.fills=fill(color);f.cornerRadius=r;f.clipsContent=true;parent.appendChild(f);return f;}
function stack(parent,name,w,color=C.surface,pad=16,gap=14,r=22){const f=box(parent,name,w,1,color,r);f.layoutMode='VERTICAL';f.primaryAxisSizingMode='AUTO';f.counterAxisSizingMode='FIXED';f.paddingTop=f.paddingBottom=f.paddingLeft=f.paddingRight=pad;f.itemSpacing=gap;return f;}
function txt(parent,value,size,w,color=C.ink,bold=false){const t=figma.createText();t.fontName={family:'Noto Sans SC',style:bold?'Bold':'Regular'};t.fontSize=size;t.lineHeight={unit:'PERCENT',value:150};t.characters=value;t.fills=fill(color);t.resize(w,1);t.textAutoResize='HEIGHT';parent.appendChild(t);return t;}
function line(parent,label,w,s,color=C.ink,bold=false){return txt(parent,label,14*s,w,color,bold);}
function field(parent,label,value,w,s,arrow=false){const g=stack(parent,label,w,C.surface,0,14,0);line(g,label,w,s,C.ink,true);const f=stack(g,'Input / '+label,w,C.surface,12,0,16);f.strokes=fill(C.border);f.strokeWeight=1;txt(f,value+(arrow?'  ▾':''),16*s,w-24);return g;}
function button(parent,label,w,s,kind='primary'){const f=stack(parent,'Button / '+label,w,kind==='primary'?C.rose:kind==='disabled'?C.neutral:C.surface,10,0,16);f.counterAxisAlignItems='CENTER';if(kind==='outline'){f.strokes=fill(C.border);f.strokeWeight=1;}const t=txt(f,label,13*s,w-20,kind==='primary'?C.surface:kind==='disabled'?C.secondary:C.rose,true);t.textAlignHorizontal='CENTER';if(f.height<44)f.paddingTop=f.paddingBottom=(44-t.height)/2;return f;}
function draw({state,s=1,w=390,h=844,index=0,end=false}){
 const root=box(figma.currentPage,'Baby profile / '+state+' / '+s+'x'+(end?' / end':''),w,h,C.bg);
 root.x=80+(index%8)*470;root.y=174500+Math.floor(index/8)*1550;
 const modal=box(root,'BabyProfileEditor',w-24,Math.min(760,h-48),C.bg,24);modal.x=12;modal.y=(h-modal.height)/2;const dw=modal.width;
 const header=box(modal,'Fixed header',dw,s===2&&state==='long-name'?150:76,C.surface);const title=state==='new'?'添加宝宝':state==='long-name'?'宝宝称呼比较长也应该保持完整可读的资料':'Luna 的资料';const titleText=txt(header,title,20*s,dw-92,C.ink,true);titleText.x=16;titleText.y=16;
 const close=txt(header,'×',24,44,state==='pending'?C.secondary:C.rose);close.x=dw-60;close.y=16;
 const footer=box(modal,'Fixed save action',dw,s===2?88:76,C.surface);footer.y=modal.height-footer.height;const action=button(footer,state==='pending'?'正在保存…':state==='uncertain'?'重试确认保存':'保存宝宝资料',dw-32,s,state==='pending'?'disabled':'primary');action.x=16;action.y=16;
 const viewport=box(modal,'Scroll viewport',dw,Math.max(1,footer.y-header.height),C.bg);viewport.y=header.height;
 const content=stack(viewport,'Scrollable fields',dw,C.bg,16,14,0);const cw=dw-32;
 const basics=stack(content,'Name and birth date',cw);basics.strokes=fill(C.border);basics.strokeWeight=1;const iw=cw-32;
 field(basics,'宝宝称呼',state==='new'||state==='validation'?'宝宝称呼':state==='long-name'?'宝宝称呼比较长也应该保持完整可读':'Luna',iw,s);
 field(basics,'出生日期',state==='new'||state==='cleared'?'尚未登记':'2026-08-22',iw,s,true);
 if(!['new','cleared'].includes(state)){const clear=button(basics,'清除日期',iw,s,'text');}
 const care=stack(content,'Growth reference and feeding',cw);care.strokes=fill(C.border);care.strokeWeight=1;
 line(care,'出生记录性别',iw,s,C.ink,true);txt(care,'用于匹配生长参考范围',12*s,iw,C.secondary);
 const choice=stack(care,'Mom choice tiles',iw,C.surface,0,8,0);
 const labels=['女宝宝','男宝宝','暂不填写'];for(let j=0;j<3;j++){const b=stack(choice,labels[j],iw,s===1?C.surface:C.surface,8,0,16);b.strokes=fill((state==='new'?j===2:j===0)?C.teal:C.border);b.strokeWeight=(state==='new'?j===2:j===0)?2:1;b.fills=fill((state==='new'?j===2:j===0)?C.mint:C.surface);const t=txt(b,labels[j],14*s,iw-16,(state==='new'?j===2:j===0)?C.teal:C.secondary,true);t.textAlignHorizontal='CENTER';}
 if(s===1){choice.layoutMode='HORIZONTAL';choice.primaryAxisSizingMode='FIXED';choice.counterAxisSizingMode='AUTO';choice.resize(iw,44);for(const c of choice.children){c.resize((iw-16)/3,44);c.children[0].resize((iw-16)/3-16,1);c.children[0].textAutoResize='HEIGHT';}}
 field(care,'目前喂养方式',state==='new'?'暂未确定':'混合喂养',iw,s,true);
 txt(care,'月龄由出生日期自动计算。每个宝宝的照护记录会分开保存。',13*s,iw,C.secondary);
 if(['validation','conflict','forbidden','unavailable','uncertain'].includes(state)){const err=stack(content,'Existing feedback',cw,C.amber);let v=state==='validation'?'请填写宝宝称呼。':state==='conflict'?'记录已在其他页面更新，请重新载入后核对。':state==='forbidden'?'当前账号没有访问权限':'暂时无法载入，请稍后重试';txt(err,v,13*s,cw-32);if(state!=='validation')txt(err,'这次填写的内容仍然保留。',13*s,cw-32);if(state==='conflict')button(err,'重新载入',cw-32,s,'text');}
 if(state==='uncertain')txt(content,'保存结果还未确认。请重试确认这次保存后再修改内容。',13*s,cw,C.secondary);
 if(end||['validation','conflict','forbidden','unavailable','uncertain'].includes(state))content.y=Math.min(0,viewport.height-content.height);
 if(state==='feeding-menu'){const menu=stack(modal,'Feeding menu',dw-64,C.surface,8,0,16);menu.x=32;menu.y=Math.min(300,modal.height-menu.height-80);for(const label of ['纯亲喂母乳','瓶喂母乳','混合喂养','配方奶','暂未确定']){const item=stack(menu,label,dw-80,label==='混合喂养'?C.mint:C.surface,12,0,0);txt(item,label,16*s,dw-104);}menu.y=Math.max(80,modal.height-menu.height-92);}
 return {id:root.id,name:root.name,state,scale:s,width:w,height:h};
}

