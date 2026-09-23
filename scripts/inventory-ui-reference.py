#!/usr/bin/env python3
"""Snapshot authoritative design references and inventory the current UI surface.

This inventory intentionally never marks a page visually complete. Review evidence
is maintained in page-map.json; captures and passing old tests are not acceptance.
"""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil

APP = Path(__file__).resolve().parents[1]
DESIGN = Path(os.environ.get('MOMCOZY_DESIGN_ROOT', APP.parent.parent / 'momcozy-lab产品设计'))
OUT = APP / 'docs/ui-reference'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = 'src/pages/UserApp.tsx'
source = (DESIGN / SOURCE).read_text()
previous = json.loads((OUT / 'page-map.json').read_text()) if (OUT / 'page-map.json').exists() else []
previous = {entry['id']: entry for entry in previous}
entries = []


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def component_ref(component):
    file = SOURCE
    if component == 'DS:living-companionship':
        file = 'me-ui-optimization/02-approved-system/生活陪伴型-design-system.md'
        return {'file': 'source/' + file, 'symbol': '生活陪伴型 Design System',
                'line': 1, 'end_line': len((DESIGN / file).read_text().splitlines())}
    if component.startswith('UI:'):
        file, component = 'src/components/UI.tsx', component[3:]
    elif component.startswith('CSS:'):
        file, component = 'src/styles.css', component[4:]
        contents = (DESIGN / file).read_text()
        at = contents.find(component)
        if at < 0: return None
        line = contents.count('\n', 0, at) + 1
        return {'file': 'source/' + file, 'symbol': component, 'line': line, 'end_line': line}
    contents = (DESIGN / file).read_text()
    match = re.search(r'^(?:export (?:default )?)?function ' + re.escape(component) + r'\b', contents, re.M)
    if not match: return None
    following = re.search(r'^(?:export (?:default )?)?function ', contents[match.end():], re.M)
    end = match.end() + following.start() if following else len(contents)
    return {'file': 'source/' + file, 'symbol': component,
            'line': contents.count('\n', 0, match.start()) + 1,
            'end_line': contents.count('\n', 0, end) + 1}


def image_ref(image, group, name):
    original = DESIGN / image
    destination = OUT / group / 'reference' / (name + '.png')
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(original, destination)
    return {'file': str(destination.relative_to(OUT)), 'original': image, 'sha256': sha(original),
            'extent': 'viewport; consult source and trigger for scroll content'}


def add(id, title, component, implementation, route, kind='page', image=None, trigger='', note=''):
    reference = component_ref(component) if component else None
    row = {'id': id, 'title': title, 'kind': kind, 'design': reference,
           'implementation': implementation, 'route': route, 'trigger': trigger,
           'status': 'Need Review' if reference else 'Missing Reference',
           'implementation_status': 'present' if implementation else 'missing_or_unmapped',
           'reference_images': [], 'notes': note,
           'functional_evidence': [], 'visual_evidence': [], 'reviewed_source_sha256': None}
    if image:
        row['reference_images'].append(image_ref(image, id.split('/')[0], id.split('/')[-1]))
    if id in previous:
        for key in ['status', 'functional_evidence', 'visual_evidence', 'reviewed_source_sha256', 'review_notes']:
            if key in previous[id]: row[key] = previous[id][key]
        if reference and previous[id]['design'] is None and row['status'] == 'Missing Reference':
            row['status'] = 'Need Review'
    full = OUT / (id + '-full.png')
    viewport = OUT / (id + '-viewport.png')
    for capture in [full, viewport]:
        if capture.exists(): row['reference_images'].append({'file': str(capture.relative_to(OUT)), 'original': 'Local design render; see capture-manifest.json', 'sha256': sha(capture), 'extent': 'expanded scroll frame' if capture == full else 'original viewport'})
    entries.append(row)
    return row

# Explicit native pages, overlays and routed subflows. IDs are stable across passes.
rows = '''
common/navigation|五入口底部导航|UserShell|lib/app/mom_bottom_navigation.dart|/me /baby / /schedule /more|component
mom/home|Me 首页|HomePage|lib/modules/mom/presentation/mother_home_page.dart|/me|page
mom/knowledge|每日知识详情|DailyKnowledgeModal|lib/shared/widgets/knowledge_banner.dart|/me|dialog
mom/record-picker|记录入口选择|HomePage|lib/modules/mom/presentation/mother_home_page.dart|/me|dialog
mom/lactation|今日泌乳与趋势|HomePage|lib/modules/mom/presentation/lactation_panel.dart|/me /me/lactation|sheet
mom/lactation-edit|泌乳新增和编辑|HomePage|lib/modules/mom/presentation/lactation_panel.dart|/me /me/lactation|form
mom/other-functions|其它功能禁用入口|HomePage|lib/modules/mom/presentation/mother_home_page.dart|/me|section
baby/home|Baby 首页|BabyPage|lib/modules/baby/presentation/baby_home_page.dart|/baby|page
baby/switcher|切换宝宝|BabyPage|lib/modules/baby/presentation/baby_home_page.dart|/baby|sheet
baby/profile|宝宝资料新增编辑|BabyPage|lib/modules/baby/presentation/baby_profile_editor.dart|/baby|dialog
baby/sleep|睡眠记录|BabyPage|lib/modules/baby/presentation/baby_record_editor.dart|/baby /babies/:babyId/records|form
baby/wet|尿湿记录|BabyPage|lib/modules/baby/presentation/baby_record_editor.dart|/baby /babies/:babyId/records|form
baby/stool|便便记录|BabyPage|lib/modules/baby/presentation/baby_record_editor.dart|/baby /babies/:babyId/records|form
baby/feeding|喂养记录|BabyPage|lib/modules/baby/presentation/baby_record_editor.dart|/baby /babies/:babyId/records|form
baby/growth-entry|生长记录|BabyPage|lib/modules/baby/presentation/baby_record_editor.dart|/baby /babies/:babyId/records|form
baby/development|发展观察|BabyPage|lib/modules/baby/presentation/baby_record_editor.dart|/baby /babies/:babyId/records|form
baby/growth|生长曲线|BabyGrowthCurve|lib/modules/baby/presentation/baby_growth_curve.dart|/baby|section
baby/records|宝宝历史记录|RecordsPage|lib/modules/baby/presentation/baby_records_page.dart|/babies/:babyId/records|page
baby/knowledge|宝宝每日知识详情|DailyKnowledgeModal|lib/shared/widgets/knowledge_banner.dart|/baby|dialog
agent/home|Cozymate 会话|AgentPage|lib/features/agent_hub/agent_hub_page.dart|/|page
agent/history|会话历史|AgentPage|lib/features/agent_hub/presentation/agent_conversation_panel.dart|/|drawer
agent/attachments|附件菜单|AgentPage|lib/features/agent_hub/agent_hub_page.dart|/|popover
agent/message-menu|消息操作||lib/features/agent_hub/agent_hub_page.dart|/|popover
agent/structured-card|结构化工具结果|AgentPage|lib/features/agent_hub/artifacts/agent_artifact_panel.dart|/|component
agent/form|结构化表单||lib/features/agent_hub/artifacts/forms/agent_artifact_form_dialog.dart|/|dialog
agent/image-preview|图片预览|AgentMessageAttachments|lib/features/agent_hub/presentation/agent_image_previews.dart|/|dialog
agent/file-preview|文件附件预览|AgentMessageAttachments|lib/features/agent_hub/presentation/agent_file_previews.dart|/|component
agent/voice|语音操作|AgentPage|lib/features/agent_hub/agent_hub_page.dart|/|state
schedule/home|日程月历与当日安排|PlanPage|lib/modules/schedule/presentation/schedule_page.dart|/schedule|page
schedule/create|新增个人日程|PlanPage|lib/modules/schedule/presentation/schedule_page.dart|/schedule|dialog
schedule/edit|编辑与删除个人日程|PlanPage|lib/modules/schedule/presentation/schedule_page.dart|/schedule|dialog
schedule/task|专业任务状态菜单|PlanPage|lib/modules/schedule/presentation/schedule_page.dart|/schedule|popover
profile/more|More|MorePage|lib/modules/profile/presentation/more_page.dart|/more|page
profile/privacy|信息授权管理|PrivacyPage|lib/modules/profile/presentation/privacy_page.dart|/privacy|page
profile/account|账号和删除账号||lib/features/auth/presentation/account_page.dart|/account|page
profile/notifications|通知收件箱||lib/features/notifications/presentation/notifications_page.dart|/notifications|page
profile/notification-settings|通知设置|MorePage|lib/features/notifications/presentation/notification_settings_page.dart|/notifications/settings|page
services/catalog|专家服务列表|ServicesPage|lib/modules/services/presentation/service_catalog_page.dart|/services|page
services/package|服务详情|ServiceDetailPage|lib/modules/services/presentation/service_package_page.dart|/services/:packageId|page
services/team|专家团队|ServiceExpertTeamModal|lib/modules/services/presentation/service_catalog_page.dart|/services/:packageId|dialog
services/purchase|适用性和购买支付|ServiceDetailPage|lib/modules/services/presentation/service_purchase_dialog.dart|/services/:packageId|dialog
services/booking|预约专家时间|AppointmentPage|lib/modules/services/presentation/booking_page.dart|/services/episodes/:episodeId/booking|page
services/appointment|预约详情|AppointmentPage|lib/modules/services/presentation/appointment_detail_page.dart|/services/appointments/:appointmentId|page
services/intake|信息采集与授权|IntakePage|lib/modules/services/presentation/intake_page.dart|/services/appointments/:appointmentId/intake|page
services/consent-detail|信息使用说明|IntakePage|lib/modules/services/presentation/intake_page.dart|/services/appointments/:appointmentId/intake|dialog
services/intake-saved|首次信息采集完成|IntakePage|lib/modules/services/presentation/intake_page.dart|/services/appointments/:appointmentId/intake|dialog
services/preparation|预约与咨询准备|HomeConsultPreparation|lib/modules/consultation/presentation/room_page.dart|/services/appointments/:appointmentId/room|page
services/device-check|摄像头麦克风检测|DeviceCheckModal|lib/modules/consultation/presentation/device_check_dialog.dart|/services/appointments/:appointmentId/room|dialog
services/video-consent|视频咨询授权||lib/modules/consultation/presentation/consultation_start_dialog.dart|/services/appointments/:appointmentId/room|dialog
services/room|视频咨询|VideoPage|lib/modules/consultation/presentation/room_page.dart|/services/appointments/:appointmentId/room|page
services/room-leave|暂时离开咨询室|VideoPage|lib/modules/consultation/presentation/room_page.dart|/services/appointments/:appointmentId/room|dialog
services/summary|咨询总结|SummaryPage|lib/modules/services/presentation/consultation_summary_page.dart|/services/appointments/:appointmentId/summary|page
services/summary-task|咨询行动详情与反馈||lib/modules/services/presentation/consultation_summary_page.dart|/services/appointments/:appointmentId/summary|dialog
services/progress|服务进度|ServiceProgressPage|lib/modules/services/presentation/service_progress_page.dart|/services/episodes/:episodeId|page
services/renew|续购|RenewPage|lib/modules/services/presentation/service_renew_page.dart|/services/renew /services/episodes/:episodeId/renew|page
services/self-management|自主管理|SelfManagementPage||未实现；设计入口 /app/self-management|page
services/referral|转介|ReferralPage||未实现；设计入口 /app/referral|page
common/media|媒体资料查看||lib/features/media/presentation/media_viewer_page.dart|/media-viewer|page
common/pdf|原生 PDF 查看||lib/features/media/presentation/media_viewer_page.dart|/media-viewer|page
common/motion|动作评估||lib/features/motion_assessment/presentation/motion_assessment_page.dart|Agent 动作入口|page
common/not-found|页面不存在||lib/app/momcozy_app.dart|/404|state
common/loading|公共加载状态||lib/shared/widgets/product_feedback.dart|各页面|state
common/empty|公共空状态|UI:EmptyState|lib/shared/widgets/product_feedback.dart|各页面|state
common/error|公共错误和重试||lib/shared/widgets/product_feedback.dart|各页面|state
common/confirm|公共确认与丢弃|UI:Modal|lib/shared/widgets/confirm_discard.dart|各表单|dialog
common/success|保存和撤销反馈||lib/modules/baby/presentation/baby_saved_feedback.dart|各表单|state
common/input|输入和选择控件|CSS:.form-card select|lib/shared/widgets/choice_field.dart|各表单|component
common/theme|全局 Theme / Design Tokens|DS:living-companionship|lib/shared/design_system/momcozy_theme.dart|全局|component
'''
images = {
'common/navigation':'me-agent-style-sync/diary-followup/15-navigation-me.png',
'mom/home':'me-agent-style-sync/diary-followup/01-me-home.png',
'mom/record-picker':'me-agent-style-sync/diary-followup/03-record-chooser.png',
'mom/lactation':'me-agent-style-sync/diary-followup/05-milk-trend.png',
'mom/lactation-edit':'me-agent-style-sync/diary-followup/04-milk-entry.png',
'mom/other-functions':'me-agent-style-sync/diary-followup/03a-other-functions.png',
'agent/home':'me-agent-style-sync/diary-followup/09-agent-home.png',
'agent/history':'me-agent-style-sync/diary-followup/11-agent-history.png',
'agent/attachments':'me-agent-style-sync/diary-followup/10-agent-attachments.png',
'services/progress':'me-agent-style-sync/diary-followup/08-service-timeline.png',
'schedule/home':'me-agent-style-sync/diary-followup/15-navigation-schedule.png',
'profile/more':'me-agent-style-sync/diary-followup/15-navigation-more.png',
}
for id, name in [('home','home-390'),('switcher','baby-switcher'),('profile','baby-profile'),('sleep','睡眠-390'),('wet','尿湿-390'),('stool','便便-390'),('feeding','feeding-390'),('growth-entry','growth-entry-390'),('growth','growth-390'),('knowledge','knowledge-article')]:
    images['baby/'+id]='baby-me-style-sync/images/'+name+'.png'
for line in rows.strip().splitlines():
    id,title,component,impl,route,kind=line.split('|')
    add(id,title,component,impl,route,kind,images.get(id))

# Keep the user's later approved email/password design, without reverting auth to demo OTP.
for step,title in [('login','邮箱和 Google 登录'),('register','注册'),('verify','验证邮箱'),('forgot','忘记密码'),('reset','重置密码'),('language','语言选择'),('legal','条款和隐私链接')]:
    row=add('auth/'+step,title,'AuthPage','lib/features/auth/presentation/auth_page.dart','/login','page' if step=='login' else 'state',note='设计工程为演示邮箱 OTP；当前真实邮箱密码/Google 流程和用户 2026-09-12 已确认稿优先保留，按统一视觉复核，禁止改回固定验证码。')
    if step == 'login':
        approved = Path('/Users/lute/Downloads/ChatGPT Image 2026年9月12日 10_24_17.png')
        target = OUT/'auth/reference/user-approved-login.png'
        target.parent.mkdir(parents=True, exist_ok=True)
        if approved.exists(): shutil.copy2(approved, target)
        if target.exists(): row['reference_images'].append({'file': str(target.relative_to(OUT)), 'original': str(approved), 'sha256': sha(target), 'extent': 'user-approved full login design, 2026-09-12'})
    if step != 'login' and row['status'] != 'Completed': row['status']='Missing Reference'; row['notes']+=' 此真实认证状态没有一对一设计稿，不能把主登录参考当作完整状态验收。'
add('auth/invite','内部邀请码登录',None,'lib/features/auth/presentation/invite_auth_page.dart','/login (internalInviteOnly)','page',note='内部条件入口，是否保留由既有渠道约束决定，不能当作无引用旧页删除。')
for step in ['load','profile','delivery','birth','avatar-choice','avatar-create','avatar-review']:
    add('auth/onboarding-'+step,'首次使用 '+step,None,'lib/features/onboarding/presentation/onboarding_page.dart','/onboarding /avatar/create /avatar/review','state',note='设计工程缺少此原生首次使用流程的独立视觉稿；保留真实业务字段，待参考/设计补全。')

# Preserve every authored Me state; explicitly flag screenshots superseded by later style patches.
manifest=json.loads((DESIGN/'me-ui-optimization/05-validation/manifest.json').read_text())
for v in manifest['views']:
    n=int(v['id'])
    if 4 <= n <= 10:
        continue  # Diary states were retired with the product capability.
    group='mom' if n<20 or n in [31,38,43] else 'agent' if n==3 else 'services'
    if n==3: group='agent'
    comp='HomePage' if n<20 or n in [31,38,43,51,52] else 'ServicesPage' if n==20 else 'ServiceDetailPage' if n<=30 else 'AppointmentPage' if n<=38 else 'IntakePage' if n<=42 else 'DeviceCheckModal' if n<=46 else 'StartConsultModal' if n<=50 else 'VideoPage'
    if n==2: comp='DailyKnowledgeModal'
    if n==3: comp='AgentPage'
    if n in [51,52]: comp='AppointmentPage'
    parent='mom/home' if n in [1,11,31,38,43] else 'mom/knowledge' if n==2 else 'agent/home' if n==3 else 'mom/lactation' if n<=19 else 'services/catalog' if n==20 else 'services/package' if n<=24 else 'services/purchase' if n<=30 else 'services/booking' if n<=37 else 'services/intake' if n<=42 else 'services/device-check' if n<=46 else 'services/preparation' if n<=50 else 'services/appointment' if n<=52 else 'services/room'
    canonical=next(e for e in entries if e['id']==parent)
    add(group+'/state-'+v['id'],v['name'],comp,canonical['implementation'],canonical['route'],'state',
        'me-ui-optimization/05-validation/'+v['file'],v['trigger'],
        '2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。')

    if n == 37:
        entries[-1]['title'] = '预约确认后进入信息采集'
        entries[-1]['kind'] = 'transition'
        entries[-1]['notes'] = '09-06 的预约成功弹窗已被当前 AppointmentPage.confirm 直接进入 IntakePage 取代；旧图保留追踪，最新状态见 state-37-viewport.png。本项只验收预约确认及进入采集的边界，采集页面单独验收。'
    if n == 44:
        entries[-1]['title'] = '咨询准备-设备检测中'
        entries[-1]['notes'] = '旧图为手动开始检测；当前 DeviceCheckModal 在用户打开弹窗后自动开始，按钮在请求中禁用。最新状态见 state-44-viewport.png，关闭必须释放迟到的设备。'
    if n in [47, 48, 49]:
        entries[-1]['implementation'] = 'lib/modules/consultation/presentation/consultation_start_dialog.dart'
        entries[-1]['notes'] = '当前 StartConsultModal 为底部位置确认；原生地区能力由既有后端校验，不复制演示端仅支持 CA 的硬编码。未授权时进入本次服务的视频授权衍生弹窗；完整全局隐私页仍单列待复核。'
    if n == 50:
        entries[-1]['design'] = component_ref('PrivacyPage')
        entries[-1]['implementation'] = 'lib/modules/profile/presentation/privacy_page.dart'
        entries[-1]['route'] = '/privacy'
        entries[-1]['notes'] = '设计中去授权打开完整 PrivacyPage；本次服务的视频授权衍生弹窗不能计作此全局五项隐私设置完成。'

for group,parent,file,title in [
('baby','feeding','feeding-validation','喂养校验错误'),('baby','home','feeding-saved','喂养保存撤销'),
('baby','sleep','sleep-active','正在睡眠'),('baby','growth','empty-growth-320','缺少生长资料'),
('baby','profile','profile-short-viewport','长昵称和短屏'),
('agent','home','12-agent-error','请求失败和重试'),('agent','home','12b-agent-conversation','对话回复'),
]:
    p=next(e for e in entries if e['id']==group+'/'+parent)
    folder='baby-me-style-sync/images' if group=='baby' else 'me-agent-style-sync/diary-followup'
    add(group+'/'+file,title,'BabyPage' if group=='baby' else 'AgentPage',p['implementation'],p['route'],'state',folder+'/'+file+'.png')

# User-approved derived references are explicit specifications, never original mockups.
derived_path = OUT/'derived-reference-specs.json'
if derived_path.exists():
    derived = json.loads(derived_path.read_text())
    for e in entries:
        e['reference_kind'] = 'user-approved-image' if e['id'] == 'auth/login' else 'original'
        if e['id'] not in derived['views']: continue
        title, layout, validation = derived['views'][e['id']]
        e['title'] = title
        ref_path = OUT / (e['id'].split('/')[0] + '/derived/' + e['id'].split('/')[1] + '.md')
        ref_path.parent.mkdir(parents=True, exist_ok=True)
        ref_path.write_text('# '+title+'：衍生设计\n\n'+derived['authorization']+'\n\n'
            +'## 可追踪依据\n\n'+'\n'.join('- ['+b+'](../../'+b+')' for b in derived['basis'])+'\n\n'
            +'## 页面结构与视觉规则\n\n'+layout+'\n\n'
            +'## 交互与状态验收\n\n'+validation+'\n\n'
            +'共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。\n\n'
            +'原生实现：`'+e['implementation']+'`；入口：`'+e['route']+'`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。\n')
        e['reference_kind'] = 'derived-user-approved'
        e['derivation_basis'] = derived['basis']
        e['design'] = {'file':str(ref_path.relative_to(OUT)), 'symbol':title+'（衍生设计）', 'line':1, 'end_line':len(ref_path.read_text().splitlines())}
        e['notes'] = '用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。'
        if e['status'] == 'Missing Reference': e['status'] = 'Need Review'

# Exact source snapshot establishes provenance even for states lacking standalone long images.
source_files=[DESIGN/SOURCE,DESIGN/'src/pages/Workbench.tsx',DESIGN/'src/App.tsx',DESIGN/'src/components/UI.tsx',DESIGN/'src/components/MeOverview.tsx',DESIGN/'src/styles.css']
source_files+=list((DESIGN/'src/styles').glob('*.css'))
source_files.append(DESIGN/'src/features/baby/growthStandards.ts')
source_files.append(DESIGN/'src/features/consultation/deviceCheck.ts')
source_files.append(DESIGN/'src/features/consultation/appointments.ts')
source_files += [DESIGN/'me-ui-optimization/02-approved-system/生活陪伴型-design-system.md',DESIGN/'me-agent-style-sync/README.md',DESIGN/'baby-me-style-sync/README.md']
provenance=[]
for src in source_files:
    rel=src.relative_to(DESIGN);target=OUT/'source'/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,target)
    provenance.append({'source':str(rel),'snapshot':str(target.relative_to(OUT)),'sha256':sha(src)})
(OUT/'source-manifest.json').write_text(json.dumps({'root':str(DESIGN),'files':provenance},ensure_ascii=False,indent=2)+'\n')

# Implementation coverage includes composed widgets; it does not imply visual approval.
related = {
    'common/navigation': ['lib/core/observability/momcozy_observability.dart', 'lib/app/momcozy_app.dart', 'lib/app/mom_module_routes.dart', 'lib/app/baby_module_routes.dart', 'lib/features/app_pages/momcozy_feature_pages.dart'],
    'common/motion': ['lib/features/motion_assessment/presentation/motion_pose_overlay.dart', 'lib/features/motion_assessment/data/motion_pose_platform.dart'],
    'auth/login': ['lib/features/auth/presentation/auth_login_chrome.dart', 'lib/shared/widgets/momcozy_wordmark.dart'],
    'agent/structured-card': ['lib/features/agent_hub/artifacts/cards/agent_artifact_card_registry.dart', 'lib/features/agent_hub/artifacts/cards/agent_result_card.dart'],
    'agent/attachments': ['lib/features/agent_hub/presentation/agent_attachment_tile.dart', 'lib/features/agent_hub/presentation/agent_image_previews.dart', 'lib/features/agent_hub/presentation/agent_file_previews.dart'],
    'agent/file-preview': ['lib/features/agent_hub/presentation/agent_attachment_tile.dart'],
    'agent/image-preview': ['lib/features/agent_hub/presentation/agent_attachment_tile.dart', 'lib/features/media/presentation/media_viewer_header.dart', 'lib/features/media/presentation/media_viewer_feedback.dart'],
    'agent/message-menu': ['lib/features/agent_hub/presentation/agent_message_menu.dart'],
    'agent/voice': ['lib/features/agent_hub/presentation/agent_voice_notice.dart'],
    'agent/form': ['lib/features/agent_hub/artifacts/forms/agent_artifact_form.dart'],
    'profile/notification-settings': ['lib/features/notifications/presentation/notification_permission_dialogs.dart'],
    'profile/notifications': ['lib/features/notifications/presentation/appointment_reminder_tile.dart'],
    'auth/onboarding-avatar-review': ['lib/features/onboarding/presentation/avatar_task_banner.dart'],
    'common/media': ['lib/features/media/presentation/product_asset_image.dart', 'lib/features/media/presentation/product_asset_video_player.dart', 'lib/features/media/presentation/media_viewer_header.dart', 'lib/features/media/presentation/media_viewer_feedback.dart'],
    'common/pdf': ['lib/features/media/presentation/pdf_document_toolbar.dart'],
    'common/loading': ['lib/shared/widgets/momcozy_components.dart'],
    'common/success': ['lib/modules/mom/presentation/lactation_panel.dart', 'lib/shared/design_system/momcozy_theme.dart'],
    'common/input': ['lib/shared/widgets/date_time_picker.dart', 'lib/shared/widgets/zoned_datetime_field.dart', 'lib/shared/design_system/momcozy_theme.dart'],
    'common/theme': ['lib/shared/design_system/momcozy_design_system.dart', 'lib/shared/design_system/momcozy_motion.dart', 'lib/shared/design_system/momcozy_text_roles.dart', 'lib/shared/widgets/momcozy_line_icon.dart', 'lib/shared/widgets/warm_editor_header.dart'],
    'services/purchase': ['lib/shared/widgets/product_flow_dialog.dart'],
    'services/booking': ['lib/modules/services/presentation/booking_flow_dialogs.dart', 'lib/modules/services/presentation/service_expert_identity.dart', 'lib/modules/services/presentation/service_flow_theme.dart'],
    'services/intake': ['lib/modules/services/presentation/service_flow_theme.dart', 'lib/shared/widgets/product_flow_dialog.dart', 'lib/modules/services/presentation/service_expert_identity.dart'],
    'services/room': ['lib/modules/consultation/presentation/video_stage.dart', 'lib/modules/consultation/presentation/user_video_stage.dart', 'lib/modules/services/presentation/appointment_summary.dart'],
    'services/preparation': ['lib/modules/consultation/presentation/consultation_preparation.dart', 'lib/shared/widgets/product_flow_dialog.dart'],
    'services/progress': ['lib/modules/services/presentation/service_timeline.dart'],
    'services/summary': ['lib/modules/services/presentation/consultation_summary_content.dart'],
    'services/appointment': ['lib/modules/services/presentation/appointment_detail_card.dart', 'lib/modules/services/presentation/appointment_cancel_dialog.dart'],
    'mom/home': ['lib/modules/services/presentation/expert_support_section.dart', 'lib/modules/mom/presentation/mother_status_card.dart'],
    'mom/lactation': ['lib/modules/mom/presentation/lactation_page.dart', 'lib/modules/mom/presentation/lactation_chart.dart'],
    'baby/home': ['lib/modules/baby/presentation/baby_overview_cards.dart', 'lib/modules/baby/presentation/baby_saved_feedback.dart'],
    'baby/feeding-saved': ['lib/modules/baby/presentation/baby_saved_feedback.dart'],
    'baby/sleep': ['lib/modules/baby/presentation/baby_record_fields.dart'],
    'baby/sleep-active': ['lib/modules/baby/presentation/baby_record_fields.dart'],
    'schedule/create': ['lib/modules/schedule/presentation/personal_schedule_editor.dart'],
    'schedule/edit': ['lib/modules/schedule/presentation/personal_schedule_editor.dart'],
}
for state in ['mom/state-31', 'mom/state-38', 'mom/state-43']:
    related[state] = ['lib/modules/services/presentation/expert_support_section.dart']
related['mom/state-43'] += ['lib/modules/consultation/presentation/home_consultation_dialog.dart', 'lib/modules/consultation/presentation/room_page.dart', 'lib/modules/consultation/presentation/consultation_preparation.dart']
for e in entries: e['related_implementation'] = related.get(e['id'], [])

# Apply the later, user-provided Mom homepage handoff without reviving its old reference.
home_override = OUT / 'mom/handoff-20260913/page-map-override.json'
if home_override.exists():
    overrides = json.loads(home_override.read_text())
    for entry in entries:
        if entry['id'] in overrides:
            entry.update(overrides[entry['id']])

# Design aliases are recorded separately from canonical native routes.
design_routes = []
for m in re.finditer(r'<Route path="([^"]+)" element=\{<(\w+)', source):
    path, component = m.groups()
    candidates = [e for e in entries if e['design'] and e['design']['symbol'] == component and e['kind'] != 'state']
    design_routes.append({'path': '/app/'+path, 'component': component, 'line': source.count('\n',0,m.start())+1,
                          'native_candidates': [{'id':e['id'], 'route':e['route']} for e in candidates],
                          'notes': '设计别名；同组件多状态需按页面条目核查，未代表逐路由验收。'})
design_routes += [{'path':'/app/agent','component':'AgentPage','native_candidates':[{'id':'agent/home','route':'/'}]},
                  {'path':'/auth','component':'AuthPage','native_candidates':[{'id':'auth/login','route':'/login'}]}]
(OUT/'design-routes.json').write_text(json.dumps(design_routes,ensure_ascii=False,indent=2)+'\n')

# Inventory every native presentation file and overlay call; all are review candidates, never auto-excluded.
impl=[]
for f in (APP/'lib').rglob('*.dart'):
    s=f.read_text();widgets=re.findall(r'class\s+(\w+)\s+extends\s+(?:StatefulWidget|StatelessWidget|State<[^>]+>)',s)
    overlays=[{'line':s.count('\n',0,m.start())+1,'call':m.group()} for m in re.finditer(r'\b(?:showDialog|showModalBottomSheet|showGeneralDialog|showCupertinoDialog|showDatePicker|showTimePicker|showMomCozyDatePicker|showMomCozyTimePicker|showMenu)\b',s)]
    routes=[{'line':s.count('\n',0,m.start())+1,'path':m.group(1)} for m in re.finditer(r'''path:\s*['"]([^'"]+)['"]''',s)]
    if not str(f.relative_to(APP)).startswith(('lib/app/', 'lib/features/ibclc/')): routes = []
    if widgets or overlays or routes:
        rel=str(f.relative_to(APP));impl.append({'file':rel,'sha256':sha(f),'widgets':widgets,'overlays':overlays,'routes':routes,'scope':'workbench-excluded' if '/ibclc/' in rel or rel.endswith('main_ibclc.dart') or rel.endswith(('/device_preview_dialog.dart', '/month_selector.dart')) else 'user-app','mapped_views':[e['id'] for e in entries if e['implementation']==rel or rel in e['related_implementation']]})
(OUT/'implementation-inventory.json').write_text(json.dumps(impl,ensure_ascii=False,indent=2)+'\n')
for e in entries:
    if e['implementation'] and not (APP/e['implementation']).exists():
        e['implementation_status']='path_needs_review'
    f=OUT/(e['id']+'.md');f.parent.mkdir(parents=True,exist_ok=True)
    ref=e['design']; relprefix='../' * len(Path(e['id']).parts[:-1])
    reftext=f"[{ref['symbol']}]({relprefix}{ref['file']}#L{ref['line']})，第 {ref['line']}–{ref['end_line']} 行" if ref else '尚无独立设计参考；禁止将旧实现截图冒充设计稿。'
    text=f"# {e['title']}\n\n- ID：`{e['id']}`\n- 类型：{e['kind']}\n- 参考来源：{e.get('reference_kind', 'original')}\n- 设计源码：{reftext}\n- Flutter：`{e['implementation'] or '尚未确认对应实现'}`\n- Route / 入口：`{e['route']}`\n- 触发：{e['trigger'] or '从对应页面或父页面进入，具体交互待逐页复核'}\n- 状态：**{e['status']}**\n\n{e['notes']}\n\n"
    for im in e['reference_images']:text+=f"[查看参考图]({relprefix}{im['file']})\n\n原始路径：`{im['original']}`；SHA-256：`{im['sha256']}`。\n\n"
    if e.get('review_notes'): text+='\n复核记录：'+e['review_notes']+'\n\n'
    for kind in ['functional_evidence','visual_evidence']:
        for evidence in e[kind]: text+=f"- {kind}: [{evidence}]({relprefix}{evidence})\n"
    text+='\n验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。\n'
    f.write_text(text)
(OUT/'page-map.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2)+'\n')
counts={status:sum(e['status']==status for e in entries) for status in ['Completed','Need Review','Missing Reference']}
text='# 用户 App 页面映射与验收进度\n\n范围：用户 App 全部页面、嵌套流程、弹窗及状态。IBCLC 仅单独登记，不在重构范围。\n\n此表是当前进度事实来源；2026-09-09 / 09-11 旧审计的“完成”不继承。\n\n'
text+=f"Total Pages / UI views: **{len(entries)}** · Completed: **{counts['Completed']}** · Need Review: **{counts['Need Review']}** · Missing Reference: **{counts['Missing Reference']}**\n\n"
text+=f"原始独立稿件缺少的 {sum(e.get('reference_kind') == 'derived-user-approved' for e in entries)} 个条目已按用户确认建立衍生规范；原稿缺失与衍生规范覆盖不混为一谈。衍生页仍需逐项实现和验收。\n\n"
text+='计数单位是独立可验收的页面/弹窗/状态，状态不冒充独立路由。当前为首轮盘点，未映射的组件及内联弹窗见 implementation-inventory.json，必须补审后才能宣称完整。\n\n| 设计页面 / 状态 | 当前 App 页面 | Route / 入口 | 实现盘点 | 验收状态 |\n| --- | --- | --- | --- | --- |\n'
for e in entries:text+=f"| [{e['title']}]({e['id']}.md) | `{e['implementation'] or '待确认/缺失'}` | `{e['route']}` | {e['implementation_status']} | {e['status']} |\n"
text+='\n## 待补盘点（不是已完成）\n\n- 内联弹窗、动态 Agent 卡片、权限/离线/处理中、原生媒体系统界面逐项复核。\n- 设计端独有功能查清为业务差异、不可用占位或缺失 UI；不得凭名称删除。\n- 登录使用用户最近确认的设计，保留真实认证协议；其它没有原稿的流程单独标注。\n- 滚动页面继续补长图；viewport 图只证明可见区域。\n- 原始产品设计中以前的 inventory/探索图不凌驾于当前 CSS 和后续定稿。\n'
(OUT/'page-map.md').write_text(text)
workbench=[x for x in impl if x['scope']=='workbench-excluded']
(OUT/'workbench/inventory.json').write_text(json.dumps(workbench,ensure_ascii=False,indent=2)+'\n')
workbench_source = (DESIGN/'src/pages/Workbench.tsx').read_text()
workbench_design = [{'component':m.group(1), 'line':workbench_source.count('\n',0,m.start())+1} for m in re.finditer(r'^(?:export (?:default )?)?function (\w+)',workbench_source,re.M)]
(OUT/'workbench/design-pages.json').write_text(json.dumps(workbench_design,ensure_ascii=False,indent=2)+'\n')
(OUT/'workbench/README.md').write_text('# IBCLC 工作台：仅登记\n\n用户于 2026-09-12 明确排除本次重构。原生入口为 `lib/main_ibclc.dart`，设计入口为 `/ibclc/*`。完整文件、路由和弹窗调用清单见 [inventory.json](inventory.json)，设计组件见 [design-pages.json](design-pages.json)。不计入用户 App 完成数。\n')
print(json.dumps({'total_views':len(entries),**counts,'ui_files':len(impl),'unmapped_user_files':sum(not x['mapped_views'] and x['scope']=='user-app' for x in impl)},ensure_ascii=False))
