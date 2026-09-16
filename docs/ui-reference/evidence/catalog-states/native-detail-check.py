import sys,subprocess,time
sys.path.insert(0,'/tmp')
from momcozy_ui import ADB,tap,capture
pkg='com.momcozymai.app.flutterpoc.local'
root='/Users/lute/project/momcozy-lab/app/docs/ui-reference/evidence/catalog-states/'
for id in sys.argv[1:]:
 subprocess.run(ADB+['shell','am','force-stop',pkg],check=True)
 subprocess.run(ADB+['shell','am','start','-n',pkg+'/com.momcozymai.momcozy_flutter_app.MainActivity','--es','momcozy.flutter.extra.NAV_PATH','/services/'+id],check=True,stdout=subprocess.DEVNULL)
 time.sleep(1)
 capture(root+'native-'+id+'-top')
 subprocess.run(ADB+['shell','input','swipe','620','2250','620','1230','350'],check=True)
 capture(root+'native-'+id+'-bottom')
 tap('购买');capture(root+'native-'+id+'-confirm');tap('关闭')
 print(id+' verified',flush=True)
