#!/usr/bin/env python3
"""Capture native notification permission gates for the integration inventory.

Requires /tmp/momcozy-native-permission-backup/backup.json from the read-only
preflight. It must describe the original APK and absent plugin preferences.
Runs isolated business data with the actual Android permission plugin. Restores
notification permission and the original APK in finally, without clearing data.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

APP = Path(__file__).resolve().parents[1]
TOOLS = Path('/Users/lute/.local/share/momcozy-toolchains')
PKG = 'com.momcozymai.app.flutterpoc.local'
ADB = [str(TOOLS/'android-sdk/platform-tools/adb'), '-s', 'emulator-5554']
OUT = APP/'docs/app-ui-inventory/native/notification-permission'
BACKUP = Path('/tmp/momcozy-native-permission-backup')
PREF = 'shared_prefs/momcozy_notification_permission.xml'
PERM = 'android.permission.POST_NOTIFICATIONS'

def adb(*args, check=True):
    return subprocess.run([*ADB, *args], capture_output=True, check=check)

def shell(*args, check=True):
    return adb('shell', *args, check=check).stdout.decode().strip()

def dump():
    shell('uiautomator', 'dump', '/sdcard/native-permission-host.xml')
    return shell('cat', '/sdcard/native-permission-host.xml')

def reset_permission():
    # A permission Activity may outlive a failed Flutter test. Dismiss only
    # this App's visible request before stopping its process.
    activities = shell('dumpsys', 'activity', 'activities')
    if any('topResumedActivity=' in line and 'permissioncontroller' in line for line in activities.splitlines()):
        xml = dump()
        if 'Allow Momcozy Lab to send you notifications?' in xml:
            shell('input', 'keyevent', '4')
    shell('am', 'force-stop', PKG)
    shell('pm', 'revoke', PKG, PERM)
    shell('pm', 'clear-permission-flags', PKG, PERM, 'user-set', 'user-fixed')
    shell('run-as', PKG, 'rm', '-f', PREF, PREF+'.bak')

def permission_line():
    return next(s.strip() for s in shell('dumpsys', 'package', PKG).splitlines()
                if s.strip().startswith(PERM+': granted='))

def click_node(xml, resource_id):
    nodes = [n for n in ET.fromstring(xml).iter('node')
             if n.get('resource-id') == resource_id and n.get('enabled') == 'true']
    assert len(nodes) == 1, f'Expected one visible control: {resource_id}'
    node = nodes[0]
    x1,y1,x2,y2 = map(int, re.findall(r'\d+', node.get('bounds')))
    shell('input', 'tap', str((x1+x2)//2), str((y1+y2)//2))
    return dict(node.attrib)

def main():
    parser = argparse.ArgumentParser();parser.add_argument('--branch',choices=['deny','allow'],required=True)
    parser.add_argument('--check-only',action='store_true')
    args = parser.parse_args();branch = args.branch
    ledger = json.loads((BACKUP/'backup.json').read_text())
    assert not ledger['plugin_preferences_existed'], 'Preserve pre-existing permission plugin preferences'
    assert 'granted=false' in ledger['permission_before'] and 'USER_SET' not in ledger['permission_before']
    original = Path(ledger['original_apk'])
    assert hashlib.sha256(original.read_bytes()).hexdigest() == ledger['original_apk_sha256']
    current_apk = shell('pm','path',PKG).removeprefix('package:')
    assert shell('sha256sum',current_apk).split()[0] == ledger['original_apk_sha256'], 'Installed APK changed; refresh the backup before any mutation'
    assert permission_line() == ledger['permission_before'], 'Permission changed since backup'
    assert 'momcozy_notification_permission.xml' not in shell('run-as',PKG,'ls','shared_prefs').splitlines(), 'Permission history changed since backup'
    if args.check_only:
        print('Read-only baseline check passed');return
    OUT.mkdir(parents=True,exist_ok=True)
    events=[];handled=set();process=None
    def capture(name, phase, xml, previous, trigger):
        png=adb('exec-out','screencap','-p').stdout
        assert png.startswith(b'\x89PNG')
        (OUT/(name+'.png')).write_bytes(png);(OUT/(name+'.xml')).write_text(xml)
        events.append({'state':name,'file':name+'.png','xml':name+'.xml','phase':phase,
                       'previous':previous,'trigger':trigger,'route':'/notifications/settings',
                       'sha256':hashlib.sha256(png).hexdigest(),'xml_sha256':hashlib.sha256(xml.encode()).hexdigest()})
        (OUT/f'native-permission-{branch}-system-journeys.json').write_text(json.dumps(events,ensure_ascii=False,indent=2))
    try:
        ledger['restore_required']=True
        (BACKUP/'backup.json').write_text(json.dumps(ledger,indent=2))
        reset_permission()
        shell('run-as',PKG,'rm','-f','app_flutter/native-permission-phase.json')
        env=os.environ.copy();env.update(JAVA_HOME=str(TOOLS/'jdk/jdk-17.0.19+10/Contents/Home'),ANDROID_HOME=str(TOOLS/'android-sdk'),ANDROID_SDK_ROOT=str(TOOLS/'android-sdk'))
        env['ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride']=str(TOOLS/'android-sdk/build-tools/36.0.0/aapt2')
        cmd=[str(TOOLS/'flutter/bin/flutter'),'test','--no-pub','--no-uninstall','--flavor','local','-d','emulator-5554',
             'integration_test/notification_native_permission_test.dart','--reporter','expanded',f'--dart-define=NATIVE_PERMISSION_ALLOW={str(branch=="allow").lower()}']
        log=APP/f'docs/app-ui-inventory/00-overview/native-permission-{branch}-final.log'
        (log.with_suffix('.command.json')).write_text(json.dumps({'command':cmd,'aapt2_override':env['ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride']},indent=2))
        with log.open('w') as f:
            process=subprocess.Popen(cmd,cwd=APP,env=env,stdout=f,stderr=subprocess.STDOUT)
            deadline=time.monotonic()+480
            while process.poll() is None:
                if time.monotonic()>deadline:raise TimeoutError('Native permission integration exceeded eight minutes')
                raw=shell('run-as',PKG,'cat','app_flutter/native-permission-phase.json',check=False)
                try:phase=json.loads(raw)
                except (ValueError,TypeError):time.sleep(.3);continue
                key=(phase.get('branch'),phase.get('phase'))
                if key[0]!=branch or key in handled:time.sleep(.3);continue
                xml=dump();name=f'native-permission-{branch}-{phase["phase"]}'
                if phase['action'] in ['allow','deny']:
                    rid=f'com.android.permissioncontroller:id/permission_{phase["action"]}_button'
                    if rid not in xml:time.sleep(.3);continue
                    capture(name,phase['phase'],xml,phase['previous'],f'App Continue → actual Android request; choose {phase["action"]}')
                    control=click_node(xml,rid);events[-1]['clicked_control']=control
                    print('Clicked actual Android',control.get('text'),flush=True)
                elif phase['action']=='enable-settings':
                    rid='android:id/switch_widget'
                    if rid not in xml or 'com.android.settings' not in xml:time.sleep(.3);continue
                    node=next(n for n in ET.fromstring(xml).iter('node') if n.get('resource-id')==rid)
                    assert node.get('checked')=='false'
                    capture(name,phase['phase'],xml,phase['previous'],'App Open settings → Android notification master switch off')
                    events[-1]['clicked_control']=click_node(xml,rid)
                    time.sleep(.4);xml=dump()
                    node=next(n for n in ET.fromstring(xml).iter('node') if n.get('resource-id')==rid)
                    assert node.get('checked')=='true'
                    previous=name;name=f'native-permission-{branch}-system-settings-on'
                    capture(name,'system-settings-on',xml,previous,'Turn on Android master switch → enabled; system Back returns to App')
                    shell('input','keyevent','4')
                    print('Enabled Android notification switch and returned',flush=True)
                else:raise ValueError(phase['action'])
                (OUT/f'native-permission-{branch}-system-journeys.json').write_text(json.dumps(events,ensure_ascii=False,indent=2))
                # Ack content identifies the last real system screenshot for the next App state.
                ack=phase['ack'];assert ack.startswith(f'/data/user/0/{PKG}/app_flutter/native-permission-{branch}-') and ack.endswith('.ack')
                adb('shell','run-as',PKG,'sh','-c',f"'printf %s {name} > {ack}'")
                handled.add(key)
            code=process.wait()
        print('Flutter test exit',code,flush=True)
        if code:raise RuntimeError(f'Flutter integration failed; inspect {log}')
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            try:process.wait(timeout=10)
            except subprocess.TimeoutExpired:process.kill();process.wait()
        # Export only this test's non-sensitive inventory artifacts.
        names=shell('run-as',PKG,'ls','app_flutter',check=False).splitlines()
        for name in names:
            if name.startswith(f'native-permission-{branch}-') and name.endswith(('.png','.json')):
                (OUT/name).write_bytes(adb('exec-out','run-as',PKG,'cat','app_flutter/'+name).stdout)
        reset_permission()
        installed=adb('install','-r',str(original));assert b'Success' in installed.stdout
        component=shell('cmd','package','resolve-activity','--brief',PKG).splitlines()[-1]
        assert component.startswith(PKG+'/')
        shell('am','start','-n',component)
        time.sleep(1)
        actual=permission_line();assert actual==ledger['permission_before'],(actual,ledger['permission_before'])
        path=shell('pm','path',PKG).removeprefix('package:')
        actual_sha=shell('sha256sum',path).split()[0];assert actual_sha==ledger['original_apk_sha256']
        xml=dump();(OUT/f'{branch}-restored-home.xml').write_text(xml)
        (OUT/f'{branch}-restored-home.png').write_bytes(adb('exec-out','screencap','-p').stdout)
        assert 'Mia' in xml,'Original authenticated home not yet verified'
        pref_present='momcozy_notification_permission.xml' in shell('run-as',PKG,'ls','shared_prefs').splitlines()
        assert not pref_present
        restore={'apk_sha256':actual_sha,'permission_before':ledger['permission_before'],'permission_after':actual,
                 'plugin_preferences_existed_before':False,'plugin_preferences_exist_after':pref_present,'mia_visible':True,
                 'method':'install -r; no app data clear; restore only tested permission and plugin requested flag'}
        (OUT/f'{branch}-restore.json').write_text(json.dumps(restore,indent=2))
        ledger['restore_required']=False;(BACKUP/'backup.json').write_text(json.dumps(ledger,indent=2))
        print('Original APK, notification flags, plugin preferences and Mia restored',flush=True)

if __name__=='__main__':main()
