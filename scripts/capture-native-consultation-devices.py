#!/usr/bin/env python3
"""Operate actual camera/mic request UI on emulator-5554 and restore baseline.
Only isolated consultation fixtures are used. No room is joined. Requires the
previous inventory APK backup and refuses an altered initial permission state.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import os
import re
import subprocess
import time
import xml.etree.ElementTree as ET

APP=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('permission_host',APP/'scripts/capture-native-notification-permissions.py')
host=importlib.util.module_from_spec(spec);spec.loader.exec_module(host)
adb,shell,dump=host.adb,host.shell,host.dump
PKG,TOOLS=host.PKG,host.TOOLS
OUT=APP/'docs/app-ui-inventory/native/consultation-devices'
BACKUP=Path('/tmp/momcozy-native-device-backup')
PERMS=['android.permission.CAMERA','android.permission.RECORD_AUDIO']

def permissions():
    text=shell('dumpsys','package',PKG)
    return {p:next(x.strip() for x in text.splitlines() if x.strip().startswith(p+': granted=')) for p in PERMS}

def restore_permissions():
    shell('am','force-stop',PKG)
    for p in PERMS:
        shell('pm','revoke',PKG,p)
        shell('pm','clear-permission-flags',PKG,p,'user-set','user-fixed')

def main():
    prior=json.loads(Path('/tmp/momcozy-native-permission-backup/backup.json').read_text())
    original=Path(prior['original_apk']);sha=hashlib.sha256(original.read_bytes()).hexdigest()
    assert sha==prior['original_apk_sha256']
    assert shell('sha256sum',shell('pm','path',PKG).removeprefix('package:')).split()[0]==sha
    before=permissions()
    for v in before.values():
        assert 'granted=false' in v and 'USER_SET' not in v and 'USER_FIXED' not in v, 'Device permission history changed; review before resetting'
    BACKUP.mkdir(exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    ledger={'original_apk':str(original),'original_apk_sha256':sha,'permission_before':before,'restore_required':False}
    existing=BACKUP/'backup.json'
    if existing.exists():assert not json.loads(existing.read_text())['restore_required'],'Earlier restore incomplete'
    existing.write_text(json.dumps(ledger,indent=2))
    if '--check-only' in os.sys.argv:
        print('Read-only device baseline check passed');return
    process=None;events=[];handled=set();phase_seen={}
    try:
        ledger['restore_required']=True;existing.write_text(json.dumps(ledger,indent=2))
        shell('run-as',PKG,'rm','-f','app_flutter/native-device-phase.json')
        env=os.environ.copy();env.update(JAVA_HOME=str(TOOLS/'jdk/jdk-17.0.19+10/Contents/Home'),ANDROID_HOME=str(TOOLS/'android-sdk'),ANDROID_SDK_ROOT=str(TOOLS/'android-sdk'))
        env['ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride']=str(TOOLS/'android-sdk/build-tools/36.0.0/aapt2')
        cmd=[str(TOOLS/'flutter/bin/flutter'),'test','--no-pub','--no-uninstall','--flavor','local','-d','emulator-5554','integration_test/consultation_native_device_test.dart','--reporter','expanded']
        log=APP/'docs/app-ui-inventory/00-overview/native-device-final.log'
        log.with_suffix('.command.json').write_text(json.dumps({'command':cmd,'aapt2_override':env['ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride']},indent=2))
        with log.open('w') as f:
            process=subprocess.Popen(cmd,cwd=APP,env=env,stdout=f,stderr=subprocess.STDOUT)
            deadline=time.monotonic()+480
            while process.poll() is None:
                if time.monotonic()>deadline:raise TimeoutError('Native device test exceeded eight minutes')
                raw=shell('run-as',PKG,'cat','app_flutter/native-device-phase.json',check=False)
                try:phase=json.loads(raw)
                except ValueError:time.sleep(.3);continue
                action=phase['phase'];assert action in ['deny','allow']
                if action in handled:time.sleep(.3);continue
                xml=dump();tree=ET.fromstring(xml)
                texts=' '.join(n.get('text','') for n in tree.iter('node'))
                device='camera' if 'take pictures and record video' in texts else 'microphone' if 'record audio' in texts else None
                if device is None or 'Momcozy Lab' not in texts:time.sleep(.3);continue
                seen=phase_seen.setdefault(action,[])
                if device in seen:time.sleep(.3);continue
                rid='com.android.permissioncontroller:id/'+('permission_deny_button' if action=='deny' else 'permission_allow_foreground_only_button')
                nodes=[n for n in tree.iter('node') if n.get('resource-id')==rid and n.get('enabled')=='true']
                if len(nodes)!=1:raise RuntimeError('Actual permission choice differs: '+texts)
                name=f'native-device-{action}-{device}'
                png=adb('exec-out','screencap','-p').stdout
                (OUT/(name+'.png')).write_bytes(png);(OUT/(name+'.xml')).write_text(xml)
                row={'state':name,'file':name+'.png','xml':name+'.xml','previous':events[-1]['state'] if seen else phase['previous'],'route':phase['route'],'trigger':f'Actual Android {device} permission → choose {action}','sha256':hashlib.sha256(png).hexdigest(),'xml_sha256':hashlib.sha256(xml.encode()).hexdigest(),'clicked_control':dict(nodes[0].attrib)}
                events.append(row)
                (OUT/'native-device-system-journeys.json').write_text(json.dumps(events,ensure_ascii=False,indent=2))
                host.click_node(xml,rid);seen.append(device);print('Clicked',action,device,flush=True)
                if len(seen)==2:
                    ack=phase['ack'];assert ack.startswith(f'/data/user/0/{PKG}/app_flutter/native-device-') and ack.endswith('.ack')
                    adb('shell','run-as',PKG,'sh','-c',f"'printf %s {name} > {ack}'")
                    handled.add(action)
            code=process.wait()
        print('Flutter test exit',code,flush=True)
        if code:raise RuntimeError('Native device test failed; see final log')
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            try:process.wait(timeout=10)
            except subprocess.TimeoutExpired:process.kill();process.wait()
        # Dismiss only this app's outstanding camera/audio request.
        xml=dump()
        if 'com.android.permissioncontroller' in xml and 'Momcozy Lab' in xml:shell('input','keyevent','4')
        for name in shell('run-as',PKG,'ls','app_flutter',check=False).splitlines():
            if name.startswith('native-device-') and name.endswith(('.png','.json')):
                (OUT/name).write_bytes(adb('exec-out','run-as',PKG,'cat','app_flutter/'+name).stdout)
        restore_permissions()
        result=adb('install','-r',str(original));assert b'Success' in result.stdout
        after=permissions();assert after==before,(before,after)
        actual_sha=shell('sha256sum',shell('pm','path',PKG).removeprefix('package:')).split()[0];assert actual_sha==sha
        component=shell('cmd','package','resolve-activity','--brief',PKG).splitlines()[-1]
        assert component.startswith(PKG+'/');shell('am','start','-n',component)
        time.sleep(1);xml=dump();assert 'Mia' in xml
        (OUT/'restored-home.xml').write_text(xml)
        (OUT/'restored-home.png').write_bytes(adb('exec-out','screencap','-p').stdout)
        record={'apk_sha256':sha,'permission_before':before,'permission_after':after,'mia_visible':True,'method':'restore original APK with install -r; no uninstall/data clear; camera and microphone revoked and original flags verified'}
        (OUT/'restore.json').write_text(json.dumps(record,indent=2))
        ledger['restore_required']=False;existing.write_text(json.dumps(ledger,indent=2));print('Original APK, Mia, camera and microphone permissions restored',flush=True)

if __name__=='__main__':main()
