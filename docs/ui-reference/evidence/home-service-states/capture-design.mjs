import {chromium} from '/Users/lute/project/momcozy-lab产品设计/node_modules/playwright-core/index.mjs';
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const page=await browser.newPage({viewport:{width:390,height:844},reducedMotion:'reduce'});page.setDefaultTimeout(10000);
await page.route('**/*',r=>{const u=new URL(r.request().url());return u.origin==='http://127.0.0.1:4181'&&!u.pathname.startsWith('/api/')?r.continue():r.abort()});
const root='/Users/lute/project/momcozy-lab/app/docs/ui-reference/mom/';
async function shot(name){await page.evaluate(()=>document.fonts.ready);await page.locator('.home-service-section').scrollIntoViewIfNeeded();await page.screenshot({path:root+name+'-viewport.png'});const s=await page.addStyleTag({content:'.user-viewport,.user-shell,.user-content{height:auto!important;max-height:none!important;overflow:visible!important}'});await page.screenshot({path:root+name+'-full.png',fullPage:true});await s.evaluate(e=>e.remove());}
try {
 await page.goto('http://127.0.0.1:4181/app/home');await page.locator('.home-service-section').waitFor();await shot('home-services-current');
 const state=await page.evaluate(()=>JSON.parse(localStorage.getItem('momcozy-care-demo-state-v1')));
 console.log(JSON.stringify({episodes:state.episodes.map(e=>({id:e.id,intake:e.intakeSubmitted})),appointments:state.appointments.map(a=>({id:a.id,episode:a.episodeId,status:a.status}))}));
 const booked=state.episodes.find(e=>e.id!=='episode-demo-unbooked'&&state.appointments.some(a=>a.episodeId===e.id));
 if(!booked)throw Error('No confirmed demo fixture');
 for(const intake of [false,true]) {
  await page.evaluate(({id,intake})=>{const key='momcozy-care-demo-state-v1',s=JSON.parse(localStorage.getItem(key));s.episodes=s.episodes.map(e=>e.id===id?{...e,intakeSubmitted:intake}:e);if(s.episode?.id===id)s.episode.intakeSubmitted=intake;const base=s.appointments.find(a=>a.episodeId===id);const appointment={...base,id:'ui-reference-confirmed',status:'confirmed',attendanceOutcome:undefined,start:new Date(Date.now()+1800000).toISOString(),end:new Date(Date.now()+5400000).toISOString(),intakeSubmitted:intake};s.appointments=[...s.appointments.filter(a=>a.episodeId!==id),appointment];s.appointment=appointment;localStorage.setItem(key,JSON.stringify(s));},{id:booked.id,intake});
  await page.reload();await page.locator('.home-service-section').waitFor();
  const label=intake?'查看预约':'填写信息';await page.getByRole('button',{name:label,exact:true}).first().waitFor();await shot('home-services-'+(intake?'ready':'intake'));
 }
} finally {await browser.close()}
