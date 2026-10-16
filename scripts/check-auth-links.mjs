// Live check of the password-reset / invite email-link flow against the real
// Supabase project. Needs the dev server running (`npm start`) and a gitignored
// .env with SUPABASE_SERVICE_ROLE_KEY, TEST_EMAIL, TEST_PASSWORD for a test account.
//   npm i --no-save playwright && node scripts/check-auth-links.mjs [path/to/.env]
// Uses admin generate_link, so no email is sent; submits the account's CURRENT
// password, which Supabase rejects, so nothing changes. Never prints secrets.
import fs from 'node:fs';
import { chromium } from 'playwright';

const env = Object.fromEntries(fs.readFileSync(process.argv[2] || '.env', 'utf8').split('\n')
  .map(l => l.match(/^\s*([A-Z_]+)\s*=\s*"?(.*?)"?\s*$/)).filter(Boolean).map(m => [m[1], m[2]]));
const URL_ = 'https://avleipfdmdgtzrhyioih.supabase.co';
const KEY = env.SUPABASE_SERVICE_ROLE_KEY, EMAIL = env.TEST_EMAIL, PASSWORD = env.TEST_PASSWORD;
if (!KEY || !EMAIL || !PASSWORD) throw new Error('need SUPABASE_SERVICE_ROLE_KEY, TEST_EMAIL, TEST_PASSWORD');
const BASE = 'http://localhost:3000/';

async function fragmentFor(type) {
  // Admin generate_link returns the link without sending an email.
  const res = await fetch(`${URL_}/auth/v1/admin/generate_link`, {
    method: 'POST',
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ type, email: EMAIL, redirect_to: BASE }),
  });
  const body = await res.json();
  if (!res.ok) throw new Error(`generate_link ${res.status}: ${body.msg || body.message}`);
  const verify = await fetch(body.action_link, { redirect: 'manual' });
  const loc = verify.headers.get('location');
  const u = new URL(loc);
  console.log(`${type}: verify ${verify.status} → redirects to ${u.origin}${u.pathname} (redirect_to sent: ${BASE})`);
  const p = new URLSearchParams(u.hash.slice(1));
  console.log(`${type}: fragment keys = ${[...p.keys()].join(',')}; type=${p.get('type')}`);
  return u.hash;
}

// Report where the dashboard's Site URL sends a link when redirect_to is omitted.
{
  const res = await fetch(`${URL_}/auth/v1/admin/generate_link`, {
    method: 'POST',
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ type: 'recovery', email: EMAIL }),
  });
  const body = await res.json();
  const v = await fetch(body.action_link, { redirect: 'manual' });
  const u = new URL(v.headers.get('location'));
  console.log(`SITE URL (no redirect_to): ${u.origin}${u.pathname}`);
  const prod = await fetch(body.action_link.replace(/redirect_to=[^&]*/, 'redirect_to=' + encodeURIComponent('https://cmc-reg.netlify.app')), { redirect: 'manual' });
  console.log(`redirect_to=https://cmc-reg.netlify.app honored? → ${new URL(prod.headers.get('location')).origin}`);
}

const browser = await chromium.launch({ channel: 'chrome' });
const state = async page => page.evaluate(() => ({
  url: location.href,
  setpw: !document.getElementById('setpw-screen').classList.contains('hidden'),
  login: !document.getElementById('login-screen').classList.contains('hidden'),
  app: document.getElementById('login-screen').classList.contains('hidden') && document.getElementById('setpw-screen').classList.contains('hidden'),
  title: document.getElementById('setpw-title').textContent,
}));
const settled = page => page.waitForFunction(() => document.getElementById('main-content').style.visibility === 'visible'
  && !document.getElementById('loading-overlay').classList.contains('visible'), null, { timeout: 30000 });

// 1. Recovery link → set-password screen, tokens stripped, current password rejected.
{
  const hash = await fragmentFor('recovery');
  const page = await browser.newPage();
  await page.goto(BASE + hash);
  await settled(page);
  const s = await state(page);
  console.log('RECOVERY screen:', JSON.stringify({ ...s, tokenInUrl: /access_token/.test(s.url) }));
  await page.fill('#setpw-password', PASSWORD);
  await page.fill('#setpw-confirm', PASSWORD + 'x');
  await page.click('#setpw-submit-btn');
  console.log('MISMATCH:', await page.textContent('#setpw-error'));
  await page.fill('#setpw-confirm', PASSWORD);
  await page.click('#setpw-submit-btn');
  await page.waitForSelector('#setpw-error.visible', { timeout: 15000 });
  console.log('SAME-PASSWORD:', await page.textContent('#setpw-error'));
  console.log('still on set-password:', (await state(page)).setpw);
  await page.close();
}

// 2. Invite-type fragment wording. generate_link type=invite only works for
// users who don't exist yet, so reuse a real recovery session and relabel it.
{
  const hash = (await fragmentFor('recovery')).replace('type=recovery', 'type=invite');
  const page = await browser.newPage();
  await page.goto(BASE + hash);
  await settled(page);
  console.log('INVITE screen:', JSON.stringify(await state(page)));
  await page.close();
}

// 3. Normal password sign-in goes straight into the app.
{
  const page = await browser.newPage();
  await page.goto(BASE);
  await settled(page);
  await page.fill('#login-email', EMAIL);
  await page.fill('#login-password', PASSWORD);
  await page.click('#login-submit-btn');
  await page.waitForFunction(() => document.getElementById('login-screen').classList.contains('hidden'), null, { timeout: 30000 });
  await settled(page);
  console.log('PASSWORD SIGN-IN:', JSON.stringify(await state(page)));
  await page.close();
}
await browser.close();
