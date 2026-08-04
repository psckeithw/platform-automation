#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

(async () => {
  const email = process.env.RLDATIX_EMAIL || process.env.RLDATIX_USER;
  const password = process.env.RLDATIX_PASSWORD || process.env.RLDATIX_PASS;
  if (!email || !password) {
    console.error('Missing credentials. Set RLDATIX_EMAIL and RLDATIX_PASSWORD environment variables.');
    console.error('Example (PowerShell):');
    console.error("$env:RLDATIX_EMAIL = 'you@example.com' ; $env:RLDATIX_PASSWORD = 'yourPassword' ; node scripts/fetch_helpcenter.js");
    process.exit(1);
  }

  const target = 'https://grc-support.rldatix.com/';
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const page = await context.newPage();

  try {
    console.log('Opening', target);
    await page.goto(target, { waitUntil: 'networkidle' });

    // Try to click a "Sign in" link/button if present
    const signInCands = ['text=Sign in', 'a:has-text("Sign in")', 'button:has-text("Sign in")', 'a[href*="access/login"]', 'a[href*="login"]'];
    for (const sel of signInCands) {
      try {
        const locator = page.locator(sel);
        if ((await locator.count()) > 0) {
          await locator.first().click({ timeout: 3000 }).catch(()=>{});
          await page.waitForLoadState('networkidle').catch(()=>{});
          break;
        }
      } catch (e) {}
    }

    // Find email input
    const emailSelectors = ['input[type="email"]', 'input[name="email"]', 'input#user_email', 'input[name="user[email]"]', 'input[id*="email"]', 'input[name*="email"]', 'input[type="text"]'];
    let emailSel = null;
    for (const sel of emailSelectors) {
      const loc = page.locator(sel);
      if ((await loc.count()) > 0) {
        if (await loc.first().isVisible().catch(()=>false)) { emailSel = sel; break; }
      }
    }
    if (!emailSel) {
      console.error('Could not find an email input. You may need to complete a Cloudflare challenge or the site uses SSO.');
      await browser.close();
      process.exit(2);
    }
    await page.fill(emailSel, email);

    // Find password input
    const pwSelectors = ['input[type="password"]', 'input[name="password"]', 'input#user_password', 'input[name="user[password]"]', 'input[id*="password"]'];
    let pwSel = null;
    for (const sel of pwSelectors) {
      const loc = page.locator(sel);
      if ((await loc.count()) > 0) {
        if (await loc.first().isVisible().catch(()=>false)) { pwSel = sel; break; }
      }
    }
    if (!pwSel) {
      console.error('Could not find a password input. Aborting.');
      await browser.close();
      process.exit(3);
    }
    await page.fill(pwSel, password);

    // Submit form - try common buttons, otherwise press Enter on password
    const submitCands = ['button[type="submit"]', 'button:has-text("Sign in")', 'input[type="submit"]', 'button'];
    let didSubmit = false;
    for (const sel of submitCands) {
      try {
        const loc = page.locator(sel);
        if ((await loc.count()) > 0) {
          await loc.first().click({ timeout: 3000 }).catch(()=>{});
          didSubmit = true;
          break;
        }
      } catch (e) {}
    }
    if (!didSubmit) {
      await page.press(pwSel, 'Enter').catch(()=>{});
    }

    // Allow manual completion if 2FA or challenge appears
    console.log('Waiting for login to complete (if a challenge/2FA appears, complete it in the opened browser)...');
    await page.waitForTimeout(3000);
    // Check for signs of being signed in
    const body = await page.content();
    const signedIn = /Sign out|Log out|Sign Out|Log Out/i.test(body);
    if (!signedIn) {
      console.log('Sign-in not confirmed. Waiting 120s for manual completion...');
      try { await page.waitForTimeout(120000); } catch (e) {}
    }

    // Attempt API fetches from page context
    console.log('Attempting portal API fetches...');
    const result = await page.evaluate(async () => {
      const candidates = [
        '/api/v2/help_center/articles.json',
        '/api/v2/help_center/articles/search.json?query=release',
        '/hc/en-us/search.json?query=release%20notes'
      ];
      const out = [];
      for (const u of candidates) {
        try {
          const res = await fetch(u, { credentials: 'same-origin' });
          const txt = await res.text();
          let body;
          try { body = JSON.parse(txt); } catch(e) { body = txt; }
          out.push({ url: u, status: res.status, body });
        } catch (e) {
          out.push({ url: u, error: String(e) });
        }
      }
      return out;
    });

    const outPath = path.join(process.cwd(), 'helpcenter-fetch.json');
    fs.writeFileSync(outPath, JSON.stringify({ fetchedAt: new Date().toISOString(), result }, null, 2));
    console.log('Saved fetch results to', outPath);

  } catch (err) {
    console.error('Error:', err);
  } finally {
    console.log('Script finished — the browser was launched in non-headless mode so you can inspect or finish any challenges. Close it manually when done.');
  }
})();
