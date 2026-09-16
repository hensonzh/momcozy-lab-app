#!/usr/bin/env python3
"""Index runtime observations; candidate route matches are never acceptance."""
from collections import Counter, defaultdict
from pathlib import Path
import hashlib
import json
import os
import re
import shutil

APP = Path(__file__).resolve().parents[1]
OUT = APP/'docs/app-ui-inventory'
RAW = OUT/'raw'
MODULES = {
    '01-auth': '登录与首次使用', '03-mom': '妈妈', '04-baby': '宝宝',
    '05-agent': 'Cozymate', '06-schedule': '日程', '07-me': '账号与隐私',
    '08-expert-service': '专家服务与咨询', '09-motion': '动作评估',
    '10-global-modals': '通用界面与浮层', '11-media': '媒体',
    'workbench-excluded': 'IBCLC 工作台（单列）',
}

def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')

def module(source, producer):
    text = (source+' '+producer).lower()
    if 'ibclc' in text: return 'workbench-excluded'
    if Path(source).name.startswith('account'): return '07-me'
    if '/auth/' in text or '/onboarding/' in text: return '01-auth'
    if '/motion_assessment/' in text: return '09-motion'
    if '/baby/' in text: return '04-baby'
    if '/mom/' in text: return '03-mom'
    if '/agent_hub/' in text: return '05-agent'
    if '/schedule/' in text: return '06-schedule'
    if '/services/' in text or '/consultation/' in text: return '08-expert-service'
    if '/profile/' in text or '/notifications/' in text or '/more_design' in text: return '07-me'
    if '/media' in text or 'media-' in text: return '11-media'
    return '10-global-modals'

def producer(meta):
    matches = re.findall(r'file://'+re.escape(str(APP))+r'/(test/[^:)]+_test\.dart):(\d+)', meta['call_stack'])
    return matches[0] if matches else ('', '')

def state_key(meta):
    stem = Path(meta['source']).stem
    # Scoped redesign baselines use names such as loading/overview. Keep their
    # page namespace so they cannot merge with another page's state.
    if '/ui_refactor/lactation/' in meta['source']:
        stem = 'lactation-current-' + stem
    return re.sub(r'-(?:320|360|390|393|400|430)(?:-[12]x)?$', '', stem)

def score(meta):
    return (bool(re.search(r'-2x\.png$', meta['source'])),
            abs(meta['width']-390), meta['source'])

def table_text(value):
    return str(value).replace('|', '\\|').replace('\n', ' / ')

def main():
    class_files = defaultdict(list)
    sources = []
    for path in sorted((APP/'lib').rglob('*.dart')):
        content = path.read_text()
        classes = re.findall(r'\bclass\s+(\w+)\s+extends\s+(?:StatelessWidget|StatefulWidget)', content)
        overlays = [{'line': content.count('\n', 0, m.start())+1, 'call': m.group(0)}
                    for m in re.finditer(r'\b(?:showDialog|showModalBottomSheet|showGeneralDialog|showMenu|showSnackBar|showMomCozyDatePicker|showMomCozyTimePicker)\b', content)]
        if not classes and not overlays: continue
        rel = str(path.relative_to(APP))
        scope = 'workbench-excluded' if '/ibclc/' in rel else 'user-app'
        sources.append({'file': rel, 'classes': classes, 'overlay_calls': overlays, 'scope': scope,
                        'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        for cls in classes: class_files[cls].append(rel)
    previous = json.loads((APP/'docs/ui-reference/page-map.json').read_text())
    journeys = {row['source']: row for path in sorted((RAW/'journeys').glob('*.json'))
                for row in [json.loads(path.read_text())]}
    groups = defaultdict(list)
    for path in sorted(RAW.rglob('*.png.json')):
        meta = json.loads(path.read_text())
        meta['producer'], meta['producer_line'] = producer(meta)
        meta['metadata_file'] = str(path.relative_to(OUT))
        key = module(meta['source'], meta['producer'])+'/'+state_key(meta)
        groups[key].append(meta)
    states = []
    observed = set()
    for key, variants in sorted(groups.items()):
        primary = min(variants, key=score)
        scope = key.split('/')[0]
        directory = OUT/key
        directory.mkdir(parents=True, exist_ok=True)
        viewport = RAW/primary['source']
        long_info = primary.get('long_capture', {})
        long_path = Path(long_info.get('file', ''))
        if not long_path.is_absolute(): long_path = APP/long_path
        full = long_info.get('status') == 'complete-measured-scroll-stitch' and long_path.is_file()
        shutil.copyfile(viewport, directory/'viewport.png')
        shutil.copyfile(long_path if full else viewport, directory/'default.png')
        files = sorted({file for cls in primary['widget_types'] for file in class_files.get(cls, [])})
        observed.update(files)
        candidates = [row for row in previous if row['implementation'] in files]
        routes = sorted({row['route'] for row in candidates if row['route'].startswith('/')})
        meaningful = [t for t in primary['texts'] if t not in ['返回', '关闭', 'Me', 'Baby', 'Cozymate', 'Schedule', 'More']]
        title = (meaningful[0] if meaningful else state_key(primary)).replace('\n',' / ')[:75]
        active_overflow = long_info.get('status') != 'no-active-vertical-overflow'
        record = {'id': key, 'module': MODULES[scope], 'label': title, 'state': state_key(primary),
            'image': key+'/default.png', 'viewport': key+'/viewport.png',
            'extent': 'full-measured-scroll-stitch' if full else 'viewport',
            'needs_long_review': active_overflow and not full,
            'route_candidates': routes, 'mapped_design_candidates': [r['id'] for r in candidates],
            'production_widget_files': files,
            'evidence_kind': 'actual-widget-render-with-fixture-data',
            'normal_entry_verified': False,
            'test': primary['producer'], 'test_case': primary['test_description'],
            'metadata': primary['metadata_file'],
            'variants': [{'source': v['source'], 'metadata': v['metadata_file'],
                          'width': v['width'], 'height': v['height']} for v in variants]}
        journey = journeys.get(primary['source'])
        if journey:
            record.update(normal_entry_verified=True,
                          evidence_kind='actual-app-router-with-isolated-http-fixtures',
                          verified_route=journey['route'], entry=journey['root_entry'],
                          trigger=journey['trigger'], journey=journey,
                          route_candidates=[journey['route']])
        states.append(record)
        md = f"# {title}\n\n稳定状态 ID：`{key}`\n\n![当前运行界面](default.png)\n\n"
        md += f"- 状态：`{record['state']}`\n- 范围：{record['extent']}\n- 数据：组件测试的合成数据，不代表生产账户业务状态。\n"
        md += f"- 实际执行：`{record['test_case']}`\n- 测试来源：[{primary['producer']}:{primary['producer_line']}]({os.path.relpath(APP/primary['producer'],directory)})\n"
        md += f"- [运行元数据、点击轨迹与滚动范围]({os.path.relpath(OUT/primary['metadata_file'],directory)})\n"
        if long_info.get('nested_editable_scrolls'):
            md += '- 长图范围：完整外层表单；内部备注输入框保持实际高度和当前滚动位置，没有将输入框内容展开为页面。输入框首尾状态需查看对应交互截图。\n'
        if journey:
            md += f"- 正常路由链：**已在实际 App 路由中执行**；{journey['root_entry']}。\n- 当前路由：`{journey['route']}`\n- 触发：{journey['trigger']}\n- 证据边界：{journey['evidence']}\n"
            md += '\n业务写操作均只请求测试传输层；不表示生产账号的数据被修改，也不代表外部服务交易已验收。\n\n'
        else:
            md += '- 正常用户入口：**待逐项核实**；下方是当前组件与既有映射推导的候选入口，不视为已遍历。\n'
            md += '\n候选入口：'+ ('、'.join(f'`{r}`' for r in routes) or '尚无路由对应；可能是内联组件/全局状态。')+'\n\n'
        md += '前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：\n\n'
        actions = primary['interactions_since_previous_capture']
        for action in actions:
            md += '- '+action['action']+'：'+(' / '.join(action['labels_at_start']) or f"坐标 {action['from']} → {action['to']}")+'\n'
        if not actions: md += '- 此观察点前没有指针操作记录；可能为直接挂载、异步状态变化或输入事件，需结合测试源码核实。\n'
        md += '\n## 其它尺寸与字号\n\n'
        for v in variants:
            md += f"- [{Path(v['source']).name}]({os.path.relpath(RAW/v['source'],directory)}) · {v['width']} × {v['height']}\n"
        (directory/'README.md').write_text(md)
    native_edges = []
    for native_manifest in [OUT/'native/media-manifest.json', OUT/'native/resource-manifest.json', OUT/'native/permission-manifest.json', OUT/'native/device-manifest.json']:
        if not native_manifest.exists(): continue
        for native in json.loads(native_manifest.read_text()):
            directory = OUT/native['id']
            directory.mkdir(parents=True, exist_ok=True)
            complete_document = native.get('full_document')
            has_document = bool(complete_document and (OUT/complete_document).is_file())
            shutil.copyfile(OUT/(complete_document if has_document else native['image']), directory/'default.png')
            files = list(native.get('production_widget_files', ['lib/features/media/presentation/media_viewer_page.dart']))
            if 'pdf' in native['id'] and 'production_widget_files' not in native:
                files.append('lib/features/media/presentation/pdf_document_toolbar.dart')
            observed.update(files)
            verified = native.get('normal_entry_verified', False)
            route = native['route']
            manifest_path = str(native_manifest.relative_to(OUT))
            record = {'id': native['id'], 'module': MODULES[native['id'].split('/')[0]], 'label': native['title'],
                'state':native['title'], 'image':native['id']+'/default.png', 'viewport':native['image'],
                'extent':'full-native-measured-scroll-stitch' if has_document else 'native-viewport',
                'needs_long_review':'pdf' in native['id'] and route == '/media-viewer' and not has_document,
                'route_candidates':[route], 'mapped_design_candidates':[],
                'production_widget_files':files, 'evidence_kind':native.get('evidence_kind', 'Android-native-integration-fixture'),
                'normal_entry_verified':verified, 'test':native['source'], 'test_case':native['trigger'],
                'metadata':manifest_path, 'variants':[]}
            if verified:
                edge = {'from':native['previous_id'], 'to':native['id'], 'source':native['image'],
                        'root_entry':native['root_entry'], 'route':route, 'trigger':native['trigger'],
                        'evidence':native['entry_evidence'], 'test':native['source'], 'metadata':manifest_path}
                native_edges.append(edge)
                record.update(journey=edge, verified_route=route, entry=native['root_entry'], trigger=native['trigger'])
            states.append(record)
            data_description = native.get('data_description', '本地合成数据与媒体资产；实际原生渲染。')
            doc = f"# {native['title']}\n\n![当前原生界面](default.png)\n\n- 入口：`{route}`\n- 触发：{native['trigger']}\n- 数据：{data_description}\n- 验证范围：{native['entry_evidence']}\n- 测试：`{native['source']}`\n- [原生截图元数据](../../{manifest_path})\n- [当前交互窗口](../../{native['image']})\n"
            if native.get('xml'):
                doc += f"- [实际系统 UI 层级](../../{native['xml']})\n"
            if verified:
                previous = native['previous_id']
                doc += f"- 起点：{native['root_entry']}\n"
                if previous: doc += f"- [前一个状态](../../{previous}/README.md)\n"
            if has_document:
                doc += f"\n默认图由实际纵向滚动拼接，页头与固定底部各保留一次；当前交互窗口单独保留。PDF 放大后保留当前横向视窗，完整页宽请查看适配宽度的 PDF 第一页长图。[测量数据](../../{native['scroll_metadata']})。\n"
            (directory/'README.md').write_text(doc)
    write_json(OUT/'manifest.json', states)
    source_states = {v['source']:s['id'] for s in states for v in s['variants']}
    verified_edges = [{**row, 'from':source_states.get(row.get('previous_source')),
                       'to':source_states.get(row['source'])} for row in journeys.values()]
    verified_edges.extend(native_edges)
    write_json(OUT/'00-overview/verified-journeys.json', verified_edges)
    journey_md = '# 已实际执行的入口链\n\n使用正式 MomCozyFlutterApp 和 createMomCozyRouter；HTTP、会话存储为隔离测试依赖。只将路由断言与截图均已发生的观察点标为已核实。\n\n| 上一状态 | 实际操作 / 条件 | 到达状态 | 路由 |\n| --- | --- | --- | --- |\n'
    for edge in verified_edges:
        prior = f"[{edge['from']}](../{edge['from']}/README.md)" if edge['from'] else table_text(edge['root_entry'])
        target = f"[{edge['to']}](../{edge['to']}/README.md)" if edge['to'] else '未采集，待补'
        journey_md += f"| {prior} | {table_text(edge['trigger'])} | {target} | `{edge['route']}` |\n"
    (OUT/'00-overview/VERIFIED-JOURNEYS.md').write_text(journey_md)
    annotations_file = OUT/'00-overview/entry-audit-overrides.json'
    annotations = json.loads(annotations_file.read_text()) if annotations_file.exists() else {}
    for source in sources:
        source['observed_in_current_capture'] = source['file'] in observed
        source['status'] = 'observed-component; entry-not-yet-audited' if source['file'] in observed else 'requires-entry-audit'
        if source['file'] in annotations: source['entry_audit'] = annotations[source['file']]
    write_json(OUT/'00-overview/source-audit.json', sources)
    observations = []
    for path in (RAW/'observations').glob('*.json'):
        row = json.loads(path.read_text()); row['producer'] = producer(row)[0]
        row['state_id'] = module(row['source'],row['producer'])+'/'+state_key(row)
        observations.append(row)
    cases = defaultdict(list)
    for row in observations: cases[(row['producer'],row['test_description'])].append(row)
    edges = []
    for (test, case), rows in cases.items():
        prev = None
        for row in sorted(rows, key=lambda r:r['sequence']):
            edges.append({'from': prev, 'to': row['state_id'], 'test':test, 'test_case':case,
                          'actions': row['interactions_since_previous_capture'],
                          'normal_route_verified':False})
            prev = row['state_id']
    write_json(OUT/'00-overview/observed-transitions.json', edges)
    control_evidence = []
    for state in states:
        if not state['variants']: continue
        meta = json.loads((OUT/state['metadata']).read_text())
        unique = {}
        for control in meta.get('controls', []):
            signature = (tuple(control['bounds']), tuple(control['labels']), control['enabled'])
            unique.setdefault(signature, control)
        control_evidence.append({'state':state['id'], 'metadata':state['metadata'],
                                 'controls':list(unique.values()),
                                 'coverage_verdict':'not-assessed; mounted controls are discovery evidence only'})
    write_json(OUT/'00-overview/control-evidence.json', control_evidence)
    counts = Counter(s['module'] for s in states)
    missing = [s for s in sources if s['scope']=='user-app' and not s['observed_in_current_capture']]
    summary = {'screenshot_entries': len(states), 'render_variants':sum(len(s['variants']) for s in states),
               'user_screenshot_entries':sum(not s['id'].startswith('workbench-excluded/') for s in states),
               'workbench_reference_entries':sum(s['id'].startswith('workbench-excluded/') for s in states),
               'primary_long_images':sum(s['extent'].startswith('full-') for s in states),
               'long_review_entries':sum(s['needs_long_review'] for s in states),
               'unobserved_widget_or_overlay_files':len(missing), 'observed_transition_steps':len(edges),
               'verified_normal_entry_states':sum(s['normal_entry_verified'] for s in states),
               'states_with_control_observations':sum(bool(s['controls']) for s in control_evidence),
               'modules':dict(counts), 'completion':'INCOMPLETE: normal entries, missing states and visual QA pending'}
    write_json(OUT/'00-overview/coverage.json', summary)
    md = '# 当前用户 App 的 UI / UX 状态地图\n\n**采集与核验进行中，尚未完成全部入口及状态覆盖。**\n\n'
    md += f"本轮已有 **{summary['user_screenshot_entries']} 个用户 App 截图条目**，另单列 {summary['workbench_reference_entries']} 个工作台参考条目；共有 {summary['render_variants']} 个尺寸/字号变体、{summary['primary_long_images']} 张主长图。这些是运行证据的数量，不等于独立页面数或完整覆盖率。\n\n"
    md += '范围见 [原始要求](00-overview/REQUEST.md)。用户 App 在范围内；IBCLC 工作台单列。截图来自当前 Flutter 运行与原生模拟器，不使用设计稿冒充界面。\n\n'
    md += '证据与待办：[完成审计与未完成项](00-overview/AUDIT.md) · [妈妈逐控件清单](00-overview/MOM-CONTROL-COVERAGE.md) · [宝宝逐控件清单](00-overview/BABY-CONTROL-COVERAGE.md) · [More 逐控件清单](00-overview/MORE-CONTROL-COVERAGE.md) · [通知逐控件清单](00-overview/NOTIFICATION-CONTROL-COVERAGE.md) · [服务逐控件清单](00-overview/SERVICE-CONTROL-COVERAGE.md) · [覆盖统计](00-overview/coverage.json) · [已执行入口链](00-overview/VERIFIED-JOURNEYS.md) · [当前注册路由](00-overview/registered-routes.json) · [源码入口审计](00-overview/source-audit.json) · [实际测试操作序列](00-overview/observed-transitions.json) · [运行日志](00-overview/capture.log) · [原生一级模块](native/)\n\n'
    md += f"已有 {summary['verified_normal_entry_states']} 个状态通过正式 App 路由链验证，其余候选入口仍待逐一核实。组件回调替身不证明后续真实路由。`.long.png` 在原始窗口中实际滚动并拼接，固定页头和导航各保留一次；多滚动区域及未完成状态单独标记。\n\n"
    for group, label in MODULES.items():
        entries = [s for s in states if s['id'].startswith(group+'/')]
        if not entries: continue
        md += f'## {label}\n\n| 页面 / 状态 | 入口及核实情况 | 运行触发 | 截图 | 范围 |\n| --- | --- | --- | --- | --- |\n'
        for row in entries:
            md += f"| [{table_text(row['state'])}]({row['id']}/README.md) | {'已核实' if row['normal_entry_verified'] else '候选'}：{table_text(' / '.join(row['route_candidates']))} | {table_text(row.get('trigger',row['test_case']))} | [图]({row['image']}) | {'长图' if row['extent'].startswith('full') else '当前窗口'} |\n"
        md += '\n'
    md += '## 复现采集\n\n```sh\npython3 scripts/capture-app-ui-inventory.py --flutter /path/to/flutter\npython3 scripts/index-app-ui-inventory.py\n```\n\n采集仅运行包含金图的视觉测试，正常测试不设置采集变量；不改变 App 运行行为。\n'
    # Keep the page catalogue as the front door once evidence has been grouped.
    index_name = 'EVIDENCE-INDEX.md' if (OUT/'00-overview/page-catalog-definition.json').exists() else 'README.md'
    (OUT/index_name).write_text(md)
    print(json.dumps(summary,ensure_ascii=False))

if __name__ == '__main__': main()
