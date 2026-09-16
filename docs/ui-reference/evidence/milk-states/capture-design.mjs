import {chromium} from '/Users/lute/project/momcozy-lab产品设计/node_modules/playwright-core/index.mjs';
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const page=await browser.newPage({viewport:{width:390,height:844},reducedMotion:'reduce'});
page.setDefaultTimeout(10000);
await page.route('**/*',r=>{const u=new URL(r.request().url());return u.origin==='http://127.0.0.1:4181'&&!u.pathname.startsWith('/api/')?r.continue():r.abort()});
const root='/Users/lute/project/momcozy-lab/app/docs/ui-reference/mom/';
async function shot(name){await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(150);await page.screenshot({path:root+'milk-'+name+'-viewport.png'});const s=await page.addStyleTag({content:'.user-viewport,.user-shell,.user-content,.modal-overlay,.modal.milk-modal{position:static!important;height:auto!important;max-height:none!important;overflow:visible!important}'});await page.screenshot({path:root+'milk-'+name+'-full.png',fullPage:true});await s.evaluate(e=>e.remove());}
try {
 await page.goto('http://127.0.0.1:4181/app/home');await page.getByRole('button',{name:/今日泌乳/}).click();
 while(await page.locator('.lactation-record-actions .danger').count()) await page.locator('.lactation-record-actions .danger').first().click();
 await page.locator('.milk-modal .modal-header button').click();await page.getByRole('button',{name:/今日泌乳/}).click();
 await page.locator('.lactation-empty').scrollIntoViewIfNeeded();await shot('empty');
 await page.getByRole('button',{name:'+ 添加一条',exact:true}).click();await shot('pump');
 await page.getByRole('button',{name:'亲喂',exact:true}).click();await shot('nurse');
 await page.getByLabel('左侧亲喂时长').fill('241');await page.getByRole('button',{name:'保存这次记录',exact:true}).click();await page.locator('.mom-editor-error').scrollIntoViewIfNeeded();await shot('validation');
 await page.getByLabel('左侧亲喂时长').fill('12');await page.locator('.lactation-optional summary').click();await page.getByRole('button',{name:'胀满',exact:true}).click();await page.getByLabel('本次泌乳备注').fill('这次右侧有些胀，先记录下来');await page.locator('.lactation-optional').scrollIntoViewIfNeeded();await shot('optional');
 await page.getByRole('button',{name:'保存这次记录',exact:true}).click();await page.getByText('这次记录已保存。',{exact:true}).scrollIntoViewIfNeeded();await shot('saved');
 await page.getByRole('button',{name:'编辑',exact:true}).click();await shot('editing');await page.getByLabel('左侧亲喂时长').fill('15');await page.getByRole('button',{name:'保存修改',exact:true}).click();
 await page.getByRole('button',{name:'删除',exact:true}).click();await page.getByRole('button',{name:'撤销',exact:true}).scrollIntoViewIfNeeded();await shot('deleted');await page.getByRole('button',{name:'撤销',exact:true}).click();await page.getByText('记录已恢复。',{exact:true}).scrollIntoViewIfNeeded();await shot('restored');
 console.log('Captured nine milk states; isolated demo with all API and external requests blocked.');
} finally {await browser.close()}
