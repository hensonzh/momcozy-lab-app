#!/usr/bin/env python3
"""Group preserved evidence by reviewed page definitions; never invent coverage."""
from pathlib import Path
from collections import defaultdict, Counter
from urllib.parse import urlsplit
from datetime import datetime, timezone
import hashlib, json, re, os
from PIL import Image

APP=Path(__file__).resolve().parents[1]
B=APP/'docs/app-ui-inventory'; O=B/'00-overview'
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,data):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
def esc(x):return str(x).replace('|',' / ').replace('\n',' ')
def link(p,base=O):return os.path.relpath(p,base)
def main():
 d=read(O/'page-catalog-definition.json'); definitions={p['id']:p for p in d['pages']}
 rows=read(B/'manifest.json'); prior={s['file']:s['sha256'] for s in read(O/'source-audit.json')}
 # Completion comes from the separate requirement-by-requirement review, not
 # from this file-indexing script. A changed source invalidates its display.
 acceptance=read(O/'final-acceptance.json') if (O/'final-acceptance.json').exists() else {}
 accepted=(acceptance.get('goal_status')=='COMPLETE'
           and acceptance.get('manifest_sha256')==sha(B/'manifest.json')
           and bool(acceptance.get('source_hashes'))
           and all((APP/f).exists() and sha(APP/f)==h for f,h in acceptance['source_hashes'].items()))
 source_hashes={p['source']:sha(APP/p['source']) for p in d['pages']+d['overlays'] if (APP/p['source']).exists()}
 changed={p for p,h in source_hashes.items() if p in prior and h!=prior[p]}
 # Index regeneration refreshes source-audit; preserve unresolved visual reviews.
 pending=O/'pending-source-reviews.json'
 if pending.exists():changed.update(read(pending)['files'])
 meta={r['id']:read(B/r['metadata']) if r['variants'] else {} for r in rows}
 routes=sorted([(route,p['id']) for p in d['pages'] for route in p['routes'] if p['id'] not in ['auth-register','auth-verify','auth-forgot','auth-reset','invite']],key=lambda x:-len(x[0]))
 def auth(r,m):
  texts=set(m.get('texts',[]));state=r['state']
  for terms,id in [({'Reset password','Reset your password'},'auth-reset'),({'Send reset code','Forgot password?'},'auth-forgot'),({'Verify and continue','Verify your email'},'auth-verify'),({'Create account','Create your account'},'auth-register')]:
   # Login has a Forgot password? navigation link; require its submit label.
   if id=='auth-forgot' and not texts&{'Send reset code', 'We’ll send a code to help you reset your password.'}:continue
   if texts&terms:return id
  for word,id in [('reset-code','auth-reset'),('verify-form','auth-verify'),('register','auth-register')]:
   if state.startswith('auth-'+word):return id
  return 'auth-login'
 def owner(r):
  if r['id'].startswith('workbench-excluded/'):return 'workbench','excluded'
  m=meta[r['id']];types=set(m.get('widget_types',[]))
  if '_ProductAssetVideoFullscreenPage' in types:return 'video-fullscreen','widget'
  if 'MomCozyInviteAuthPage' in types:return 'invite','configuration-widget'
  if 'OnboardingPage' in types:
   state=r['state']
   # These reviewed state names omit 'avatar'; retain their actual page owner.
   if state == 'onboarding-request-error':return 'avatar-create','configuration-reviewed-state'
   if state.startswith('onboarding-upload-'):return 'avatar-create','configuration-reviewed-state'
   if state.startswith('onboarding-avatar-short-'):return 'avatar-review','configuration-reviewed-state'
   if state in {'onboarding-required','onboarding-required-source','onboarding-failed','onboarding-failed-source'}:return 'avatar-create','configuration-reviewed-state'
   if any(x in state for x in ['review','candidate','activate','activation']):return 'avatar-review','configuration-inferred'
   if any(x in state for x in ['avatar','generation','generating','portrait','photo','default']):return 'avatar-create','configuration-inferred'
   return 'onboarding','configuration-inferred'
  route=r.get('verified_route')
  if not route and not r['variants'] and '/media-viewer' in r.get('route_candidates',[]):
   return ('video-fullscreen' if 'fullscreen' in r['id'] else 'media'),'native-injected-route'
  if route:
   for pattern,id in routes:
    if re.fullmatch(re.sub(r':[A-Za-z]+','[^/]+',pattern),urlsplit(route).path):return (auth(r,m) if id=='auth-login' else id),'route'
  if 'MomCozyAuthPage' in types:return auth(r,m),'widget'
  # The most specific destination is selected before background/home widgets.
  priority=['motion','not-found','intake','summary','consultation','appointment','booking','service-package','service-progress','service-renew','service-catalog','notification-settings','notifications','account','privacy','baby-records','mom-lactation','mom-diary','schedule','agent-home','baby-home','mom-home','more','media']
  for id in priority:
   if definitions[id]['widget'] in types:return id,'widget'
  aliases={'AvatarTaskBanner':'avatar-create','AgentComposerBar':'agent-home','AgentSentFiles':'agent-home','AgentSentImages':'agent-home','AgentResultCard':'agent-home','AgentMessageMenu':'agent-home','ExpertServiceCard':'mom-home','MotherDiaryEditor':'mom-diary','RestFields':'mom-diary','BodyFields':'mom-diary','MoodFields':'mom-diary','LactationPanel':'mom-lactation','BabyProfileEditor':'baby-home','BabyRecordEditor':'baby-home','BabyGrowthCurve':'baby-home','AgentArtifactPanel':'agent-home','AgentArtifactFormDialog':'agent-home','_AgentConversationPanel':'agent-home','ServicePurchaseDialog':'service-package','AppointmentDetailCard':'appointment','ConsultationDeviceCheckDialog':'consultation','ProductAssetVideoPlayer':'media'}
  for cls,id in aliases.items():
   if cls in types:return id,'component-owner'
  return 'shared-reference','shared-component-reference'
 assigned=defaultdict(list); pixel_groups=defaultdict(list); assignments=[]
 for r in rows:
  id,basis=owner(r);m=meta[r['id']];types=set(m.get('widget_types',[]))
  overlay_ids=[o['id'] for o in d['overlays'] if types&set(o['widgets'])
               and (not o.get('required_text_any') or (id in o['owners'] and set(m.get('texts',[]))&set(o['required_text_any'])))]
  with Image.open(B/r['image']) as im:
   im=im.convert('RGBA');digest=hashlib.sha256(str(im.size).encode()+im.tobytes()).hexdigest()
  item={'evidence_id':r['id'],'page_id':id,'assignment_basis':basis,'overlay_type_candidates':overlay_ids,'pixel_sha256':digest,'image':r['image'],'captured_at':m.get('captured_at'),'route_observed':r.get('normal_entry_verified',False),'test':r['test'],'trigger':r.get('trigger',r['test_case']),'metadata':r['metadata'],'source_changed_since_last_index':sorted(set(r['production_widget_files'])&changed)}
  # Test-only coordinator absence is not evidence of default-build reachability.
  if r['state'].startswith('booking-resume-current-reminder-'):
   item['configuration_note']='supportsSessionAutoRefresh=false; no NotificationCoordinator. Default build reachability is not proved.'
  assigned[id].append(item);pixel_groups[(id,digest)].append(item);assignments.append(item)
 groups=[]
 for (id,digest),items in sorted(pixel_groups.items()):
  items=sorted(items,key=lambda x:(bool(x['source_changed_since_last_index']),not x['route_observed'],x['evidence_id']))
  groups.append({'page_id':id,'pixel_sha256':digest,'representative':items[0]['evidence_id'],'aliases':[x['evidence_id'] for x in items],'image':items[0]['image']})
 # Reuse actual Flutter images from adjacent UI work; never use figma renders as app evidence.
 supplemental=[]
 for folder in sorted((APP/'docs/ui-refactor').glob('*')):
  if not folder.is_dir():continue
  hp=folder/'implementation-hashes.json'
  hashes=read(hp) if hp.exists() else {}
  valid=isinstance(hashes,dict) and bool(hashes) and all(isinstance(h,str) and (APP/f).exists() and sha(APP/f)==h for f,h in hashes.items())
  imgs=sorted(set(folder.glob('flutter-*.png'))|set((folder/'verified').glob('*.png')))
  if not imgs:continue
  supplemental.append({'directory':str(folder.relative_to(APP)),'source_hashes_current':valid,'hash_manifest':str(hp.relative_to(APP)) if hp.exists() else None,'images':[str(p.relative_to(APP)) for p in imgs],'note':'已有 Flutter 图，可复用候选；源码匹配不自动证明正常入口、全部状态或长图完整，先核对再补图。'})
 supplemental_map={'agent-home':'agent-','auth-login':'auth','auth-register':'auth','auth-verify':'auth','auth-forgot':'auth','auth-reset':'auth','invite':'auth','onboarding':'onboarding-profile','avatar-create':'onboarding-avatar','avatar-review':'onboarding-avatar','consultation':'consultation','summary':'consultation-summary','schedule':'schedule','service-renew':'service-renew','intake':'intake','appointment':'appointment-detail'}
 catalogue=[]
 for p in d['pages']:
  items=assigned[p['id']];pg=[g for g in groups if g['page_id']==p['id']]
  related=[s for s in supplemental if supplemental_map.get(p['id']) and supplemental_map[p['id']] in Path(s['directory']).name]
  status='已有截图，待状态清单核验' if items else '缺页级截图'
  if p['source'] in changed:status='已有旧图；当前源码变更，先核对复用图' if items else status
  if p['scope']=='configured':status='配置入口单列；不计默认构建缺图'
  if p['scope']=='unreachable':status='当前无正常入口；不补虚假可达图'
  review=p.get('coverage_review')
  review_current=bool(review) and all((APP/f).exists() and sha(APP/f)==h for f,h in review['source_hashes'].items())
  coverage=review['status'] if review_current else 'NOT_AUDITED: required states listed explicitly; evidence presence is not completion'
  if review_current:status='当前具名状态已核对；范围与版本见 '+review['report']
  if accepted:
   status='盘点验收完成；当前图与历史证据按页内版本说明阅读' if p['scope']!='unreachable' else '无正常入口已单列；不制造可达截图'
   coverage='REQUIREMENT_REVIEW_COMPLETE: AUDIT.md; recorded runtime and version boundaries apply'
  catalogue.append({**p,'status':status,'evidence_entries':len(items),'exact_visual_groups':len(pg),'duplicates_folded':len(items)-len(pg),'route_evidence_entries':sum(x['route_observed'] for x in items),'overlays':[o['id'] for o in d['overlays'] if p['id'] in o['owners']],'supplemental':related,'state_coverage':coverage,'source_sha256':source_hashes[p['source']]})
 payload={'generated_at':datetime.now(timezone.utc).isoformat(),'scope':'Page catalogue and evidence organization; no new screenshots or product changes','source_hashes':source_hashes,'manifest_sha256':sha(B/'manifest.json'),'pages':catalogue,'overlays':d['overlays'],'assignments':assignments,'pixel_groups':groups,'supplemental':supplemental}
 write(O/'page-catalog.json',payload)
 stats={'pages_by_scope':dict(Counter(p['scope'] for p in catalogue)),'overlay_families':len(d['overlays']),'all_evidence_entries':len(rows),'assigned_to_pages':sum(len(assigned[p['id']]) for p in catalogue),'shared_component_references':len(assigned['shared-reference']),'workbench_excluded':len(assigned['workbench']),'pixel_groups':len(groups),'exact_duplicate_entries_folded':sum(len(g['aliases'])-1 for g in groups),'supplemental_flutter_images':sum(len(s['images']) for s in supplemental),'images_deleted':0,'current_source_changed_files':sorted(changed),'completion':'NOT_PROVEN'}
 if accepted:stats['completion']='COMPLETE: separate requirement review in AUDIT.md'
 write(O/'page-catalog-summary.json',stats)
 md='# 独立页面总清单\n\n本清单是面向浏览和补图的页面入口；原始批次和截图均保留。页面、状态、字号和入口不再混为同一个计数。\n\n'+d['counting_rule']+'\n\n'
 md+=f"默认路由页面 **27 项**，Navigator 视频全屏 **1 项**；配置页面 **4 项**、无效路由页 **1 项**、当前无入口代码页面 **1 项**单列。另有 **{len(d['overlays'])} 类弹窗／浮层**，不计入独立页面数。\n\n"
 md+='[明确补图与核对队列](VISUAL-GAPS.md) · [弹窗与浮层](OVERLAY-CATALOG.md) · [重复证据归并](EVIDENCE-GROUPS.md) · [完整机器清单](page-catalog.json)\n\n'
 for scope,title in [('default','默认路由页面'),('navigator','Navigator 页面'),('configured','配置页面'),('fallback','无效入口兜底'),('unreachable','当前无正常入口')]:
  md+=f'\n## {title}\n\n| 页面 | 从哪里进入 | 已有条目 → 像素组 | 状态 |\n| --- | --- | ---: | --- |\n'
  for p in catalogue:
   if p['scope']!=scope:continue
   md+=f"| [{p['name']}](pages/{p['id']}.md) | {esc(p['entry'])} | {p['evidence_entries']} → {p['exact_visual_groups']} | {p['status']} |\n"
 md+='\n“像素组”仅合并同一页面上逐像素相同的完整默认图；并不是语义状态数。视觉相似但不相同的图仍保留，不将错误文案、选择状态或内容变化抹掉。来源仅有组件挂载时，归属为候选，不升级为正常入口证明。\n'
 (O/'PAGE-CATALOG.md').write_text(md)
 for p in catalogue:
  dest=O/'pages'/f"{p['id']}.md";dest.parent.mkdir(exist_ok=True)
  t=f"# {p['name']}\n\n[总清单](../PAGE-CATALOG.md)\n\n- 稳定页面 ID：`{p['id']}`\n- 范围：{p['scope']}\n- 入口：{p['entry']}\n- 路由：{' / '.join(p['routes']) or 'Navigator／条件入口，见来源'}\n- 实现：[{Path(p['source']).name}]({link(APP/p['source'],dest.parent)})\n- 当前结论：{p['status']}。下列证据并不自动证明所有必需状态完成。\n\n## 本页需覆盖的独立状态\n\n"+'\n'.join('- '+s for s in p['states'])+'\n\n## 归属弹窗／浮层\n\n'+('、'.join(p['overlays']) or '共享反馈／系统浮层按实际触发归属')+'\n\n## 已有图：相同像素仅列一次\n\n| 代表图与完整上下文 | 合并条目 | 实际触发 |\n| --- | ---: | --- |\n'
  if p.get('state_evidence_map'):
   t=t.replace('## 已有图：相同像素仅列一次', '## 逐状态对应\n\n| 状态 | 截图及前后操作 | 证据边界 |\n| --- | --- | --- |\n'+'\n'.join('| '+row['state']+' | '+(' · '.join(f"[{e['id'].split('/')[-1]}](../../{e['id']}/README.md)" for e in row['evidence']) or '无正常入口；见边界说明')+' | '+esc(row.get('acceptance','待验收'))+' |' for row in p['state_evidence_map'])+'\n\n## 已有图：相同像素仅列一次')
  for g in groups:
   if g['page_id']!=p['id']:continue
   item=next(x for x in assigned[p['id']] if x['evidence_id']==g['representative'])
   t+=f"| [图]({link(B/g['image'],dest.parent)}) · [入口及前驱]({link(B/g['representative']/'README.md',dest.parent)}) | {len(g['aliases'])} | {esc(item['trigger'])} |\n"
  gap_file=O/'visual-gaps.json'
  page_gaps=[g for g in read(gap_file)['items'] if g['page']==p['id']] if gap_file.exists() else []
  if p.get('inventory_reports'):
   t+='\n## 实际操作链与状态依据\n\n'+' · '.join(f'[{r}](../{r})' for r in p['inventory_reports'])+'\n'
  if p.get('review_note'):t+='\n'+p['review_note']+'\n'
  if page_gaps:
   t+='\n## 有限收尾队列进度\n\n'
   for g in page_gaps:
    t+=f"- {g['id']}：{g['status']}。[版本、证据及下一动作](../VISUAL-GAPS.md)。\n"
  if p['supplemental']:
   t+='\n## 已有改版运行图，优先复用\n\n'
   for s in p['supplemental']:
    t+=f"- [{Path(s['directory']).name}]({link(APP/s['directory']/'HANDOFF.md',dest.parent)})：{len(s['images'])} 张 Flutter 图；源码哈希{'匹配' if s['source_hashes_current'] else '尚不能确认匹配'}。需核对目标状态和长图范围。\n"
  dest.write_text(t)
 t='# 弹窗与浮层清单\n\n这些是页面的附属交互，不增加独立页面计数。类名在截图树中出现只作定位线索，不证明浮层在顶层显示。函数式弹窗、系统窗口须结合文字与点击链核对；其状态清单有限列明，不枚举字段组合。\n\n| ID / 名称 | 宿主 | 实际触发 | 需覆盖状态 | 类型观察候选数 |\n| --- | --- | --- | --- | ---: |\n'
 for x in d['overlays']:
  count=sum(x['id'] in i['overlay_type_candidates'] for i in assignments)
  t+=f"| {x['id']} / {x['name']} | {', '.join(x['owners'])} | {x['entry']} | {'；'.join(x['states'])} | {count} |\n"
 (O/'OVERLAY-CATALOG.md').write_text(t)
 t=f"# 重复证据归并\n\n{len(rows)} 个已有条目归入 {len(groups)} 个同页完整图像素组，折叠 {stats['exact_duplicate_entries_folded']} 个重复条目。没有删除原图；尺寸、前驱和操作链全部保留在原 README 中。工作台及待归属组件也保留。\n\n| 页面 | 代表证据 | 相同图的其它入口／批次 |\n| --- | --- | --- |\n"
 for g in groups:
  if len(g['aliases'])<2:continue
  t+=f"| {g['page_id']} | [{g['representative']}](../{g['representative']}/README.md) | "+'、'.join(f'[{a}](../{a}/README.md)' for a in g['aliases'][1:])+' |\n'
 t+='\n## 共享组件参考（不计独立页面）\n\n这些是单独挂载的通用设计组件参考，供所属页面复用，不制造额外页面或列为缺页。\n\n'
 for i in assigned['shared-reference']:t+=f"- [{i['evidence_id']}](../{i['evidence_id']}/README.md)：{esc(i['trigger'])}\n"
 (O/'EVIDENCE-GROUPS.md').write_text(t)
 root=B/'README.md'
 if root.exists() and '## 登录与首次使用' in root.read_text():
  (B/'EVIDENCE-INDEX.md').write_text(root.read_text())
 root.write_text("""# 用户 App 页面与状态地图

当前已完成独立页面归类、相同图片证据归并及页面状态的证据对应；待定位项已逐项处理。完整验收仍在收尾。[最新处理结果](00-overview/STATE-MAP-FINAL.md)。

- [独立页面总清单](00-overview/PAGE-CATALOG.md)：27 个默认路由页面、1 个视频全屏页面；配置页面、无效入口和不可达代码单列。
- [弹窗与浮层清单](00-overview/OVERLAY-CATALOG.md)：按宿主页面列出 34 类交互层及其状态。
- [页面与操作链对应](00-overview/PAGE-INTERACTION-MAP.md) · [浮层截图对应](00-overview/OVERLAY-EVIDENCE-MAP.md)。
- [明确补图与核对队列](00-overview/VISUAL-GAPS.md)：12 项具名收尾工作，区分缺图、旧图、缺长图和缺入口证据。
- [补图判定与复用清单](00-overview/CAPTURE-DECISIONS.md)：具体未收录状态、可直接复用项、尚待核对项分开列出。
- [归并后的页面证据](00-overview/EVIDENCE-GROUPS.md)：同页像素相同的完整图共享代表证据，保留每个入口和操作链。
- [全部原始条目](EVIDENCE-INDEX.md)：历史批次、尺寸/字号、原始窗口和逐状态 README，未删除任何图。

原要求仍是完整 Page × State × Interaction 盘点，不能用页面计数或测试通过替代完成证明。[原始要求](00-overview/REQUEST.md) · [完成审计](00-overview/AUDIT.md) · [原生截图](native/) · [机器清单](00-overview/page-catalog.json)。

更新原始证据索引后，使用安装了 Pillow 的 Python 运行 `scripts/catalog-app-ui-inventory.py`，重新归并；未补图时无需重新运行 Flutter 采集。
""".replace('34 类交互层', f"{len(d['overlays'])} 类交互层"))
 if accepted:
  root.write_text(root.read_text()
    .replace('当前已完成独立页面归类、相同图片证据归并及页面状态的证据对应；待定位项已逐项处理。完整验收仍在收尾。[最新处理结果](00-overview/STATE-MAP-FINAL.md)。',
             '用户 App UI / UX 盘点已完成。28 个常规页面及配置／兜底／无入口页面分列，213 条页面状态、35 类浮层的 166 条状态均有对应记录。[交付验收与运行边界](00-overview/AUDIT.md)。')
    .replace('[浮层截图对应](00-overview/OVERLAY-EVIDENCE-MAP.md)', '[浮层逐状态截图](00-overview/OVERLAY-STATE-MAP.md)')
    .replace('12 项具名收尾工作，区分缺图、旧图、缺长图和缺入口证据。', '12 项具名工作均已关闭，保留处理依据。')
    .replace('具体未收录状态、可直接复用项、尚待核对项分开列出。', '保留既有补图判定；最终处置以交付验收为准。'))
 print(json.dumps(stats,ensure_ascii=False))
if __name__=='__main__':main()
