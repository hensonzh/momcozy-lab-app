import {chromium} from '/Users/lute/project/momcozy-lab产品设计/node_modules/playwright-core/index.mjs';
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const page=await browser.newPage({viewport:{width:390,height:844},reducedMotion:'reduce'});
await page.route('**/*',r=>{const u=new URL(r.request().url());return u.origin==='http://127.0.0.1:4181'&&!u.pathname.startsWith('/api/')?r.continue():r.abort()});
page.setDefaultTimeout(10000);
try {
 await page.goto('http://127.0.0.1:4181/app/home');
 await page.getByRole('button',{name:/昨夜休息/}).click();

 const root='/Users/lute/project/momcozy-lab/app/docs/ui-reference/mom/';
 async function shot(name){await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(150);await page.screenshot({path:root+name+'-viewport.png'}); const style=await page.addStyleTag({content:'.user-viewport,.user-shell,.user-content,.modal-overlay,.modal,.mom-diary-modal,.mom-status-editor{position:static!important;height:auto!important;max-height:none!important;overflow:visible!important}'});await page.screenshot({path:root+name+'-full.png',fullPage:true});await style.evaluate(el=>el.remove());}
 await page.locator('.rest-optional summary').click();
 await page.locator('.rest-optional').scrollIntoViewIfNeeded();await shot('diary-rest-expanded');
 await page.getByRole('tab',{name:'身体'}).click();
 const site=page.getByRole('button',{name:'腰背',exact:true}); if(await site.getAttribute('aria-pressed')!=='true') await site.click();
 await page.getByRole('button',{name:'明显',exact:true}).click();
 await page.getByRole('button',{name:'有一点影响',exact:true}).click();
 await page.getByText('这种不适有多难受？',{exact:true}).scrollIntoViewIfNeeded();await shot('diary-body-conditional');
 await page.locator('.body-optional summary').click();await page.locator('.body-optional').scrollIntoViewIfNeeded();await shot('diary-body-pelvic');

 console.log('Captured three current diary state references; all API requests blocked.');
} finally {await browser.close()}
