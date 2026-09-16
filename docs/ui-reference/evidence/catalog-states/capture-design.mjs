import {chromium} from '/Users/lute/project/momcozy-lab产品设计/node_modules/playwright-core/index.mjs';
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const page=await browser.newPage({viewport:{width:390,height:844},reducedMotion:'reduce'});page.setDefaultTimeout(10000);
await page.route('**/*',r=>{const u=new URL(r.request().url());return u.origin==='http://127.0.0.1:4181'&&!u.pathname.startsWith('/api/')?r.continue():r.abort()});
const root='/Users/lute/project/momcozy-lab/app/docs/ui-reference/services/';
async function shot(name){await page.evaluate(()=>document.fonts.ready);await page.screenshot({path:root+name+'-viewport.png'});const s=await page.addStyleTag({content:'.user-viewport,.user-shell,.user-content{height:auto!important;max-height:none!important;overflow:visible!important}.sticky-cta{position:static!important}'});await page.screenshot({path:root+name+'-full.png',fullPage:true});await s.evaluate(e=>e.remove());}
try {
 await page.goto('http://127.0.0.1:4181/app/services');await page.locator('.package-list').waitFor();await shot('catalog-current');
 const packages=await page.evaluate(()=>JSON.parse(localStorage.getItem('momcozy-care-demo-state-v1')).packages.filter(p=>p.category==='泌乳支持').map(p=>({id:p.id,name:p.name})));
 for(const p of packages){await page.goto('http://127.0.0.1:4181/app/services/'+p.id);await page.getByRole('heading',{name:p.name+'服务包',exact:true}).waitFor();await shot('package-'+p.id);}
 console.log(JSON.stringify(packages));
} finally {await browser.close()}
