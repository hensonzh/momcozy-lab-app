from pathlib import Path
import subprocess,os,json
root=Path('/Users/lute/.local/share/momcozy-toolchains')
env=os.environ.copy();env.update(JAVA_HOME=str(root/'jdk/jdk-17.0.19+10/Contents/Home'),ANDROID_HOME=str(root/'android-sdk'),ANDROID_SDK_ROOT=str(root/'android-sdk'))
env['ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride']=str(root/'android-sdk/build-tools/36.0.0/aapt2')
args=[str(root/'flutter/bin/flutter'),'test','integration_test/input_confirmation_design_test.dart','-d','emulator-5554','--flavor','local','--no-pub','--no-uninstall','--reporter','expanded','--dart-define=MOMCOZY_API_BASE_URL=http://10.0.2.2:8769','--dart-define=MOMCOZY_AGENT_API_BASE_URL=http://10.0.2.2:8010','--dart-define=MOMCOZY_DEFAULT_USER_ID=invite-bootstrap-user','--dart-define=MOMCOZY_DEFAULT_BABY_ID=invite-bootstrap-baby','--dart-define=MOMCOZY_LOCALE=zh-CN']
with open('/tmp/input-native.log','w') as log:
 result=subprocess.run(args,cwd='/Users/lute/project/momcozy-lab/app',env=env,stdout=log,stderr=subprocess.STDOUT)
print(json.dumps({'build_exit':result.returncode,'log':'/tmp/input-native.log'}));raise SystemExit(result.returncode)
