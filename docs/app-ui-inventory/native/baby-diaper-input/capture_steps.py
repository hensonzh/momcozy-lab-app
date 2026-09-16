from pathlib import Path
import subprocess,sys,json,re,datetime,hashlib
from xml.etree import ElementTree as ET
adb='/Users/lute/.local/share/momcozy-toolchains/android-sdk/platform-tools/adb'
b=Path('/Users/lute/project/momcozy-lab/app/docs/app-ui-inventory/native/baby-diaper-input');b.mkdir(exist_ok=True)
def run(*args):return subprocess.check_output([adb,'-s','emulator-5554',*args])
def log(x):
 p=b/'actions.jsonl';p.open('a').write(json.dumps({'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),**x},ensure_ascii=False)+'\n')
mode=sys.argv[1]
if mode=='capture':
 name=sys.argv[2];run('shell','uiautomator','dump','/sdcard/momcozy-diaper.xml');xml=run('shell','cat','/sdcard/momcozy-diaper.xml');(b/(name+'.xml')).write_bytes(xml);(b/'latest.xml').write_bytes(xml)
 png=run('exec-out','screencap','-p');(b/(name+'.png')).write_bytes(png)
 nodes=[{k:n.get(k) for k in ['text','content-desc','class','package','bounds','clickable','scrollable']} for n in ET.fromstring(xml).iter('node') if n.get('text') or n.get('content-desc')]
 log({'capture':name,'png_sha256':hashlib.sha256(png).hexdigest(),'xml_sha256':hashlib.sha256(xml).hexdigest()});print(json.dumps(nodes,ensure_ascii=False))
elif mode=='tap':
 label=sys.argv[2];nodes=[n for n in ET.fromstring((b/'latest.xml').read_bytes()).iter('node') if label in [n.get('text'),n.get('content-desc'),n.get('hint')] and n.get('enabled')=='true'];nodes=([n for n in nodes if n.get('class')=='android.widget.Button'] if len(nodes)>1 else nodes);assert len(nodes)==1,(label,len(nodes));n=nodes[0];a,c,d,e=map(int,re.findall(r'\d+',n.get('bounds')));x,y=(a+d)//2,(c+e)//2;run('shell','input','tap',str(x),str(y));log({'tap':label,'bounds':n.get('bounds'),'coordinate':[x,y]})
elif mode=='back':run('shell','input','keyevent','4');log({'key':'BACK'})
