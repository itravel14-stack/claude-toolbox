#!/usr/bin/env node
// Free Firecrawl replacement: renders a page in local headless Chromium (Playwright) and prints
// clean text + links, like Firecrawl's "scrape". No API key, no credits.
//
// Usage:
//   free-scrape <url> [--scroll 5] [--links] [--json] [--wait 2000]
//   free-scrape "https://contentrewards.com/c/discover/clipping" --scroll 8 --links
//
// --scroll N   scroll to the bottom N times (loads lazy lists such as campaign boards)
// --links      also print every link (text -> href)
// --json       print {url,title,text,links} as JSON
// --wait ms    extra wait after load (default 1500)
//
// Network: only hosts the cloud environment allows will load (the BusinessIdeas
// environment allows www.youtube.com and contentrewards.com).

const { chromium } = require("playwright");

const args = process.argv.slice(2);
const url = args.find((a) => /^https?:\/\//.test(a));
const opt = (name, def) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] && !args[i + 1].startsWith("--") ? args[i + 1] : def;
};
const flag = (name) => args.includes(name);

if (!url) {
  console.error("usage: free-scrape <url> [--scroll N] [--links] [--json] [--wait ms]");
  process.exit(2);
}

(async () => {
  const proxy = process.env.HTTPS_PROXY || process.env.https_proxy;
  const browser = await chromium.launch(proxy ? { proxy: { server: proxy } } : {});
  const ctx = await browser.newContext({
    ignoreHTTPSErrors: false,
    userAgent:
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
    viewport: { width: 1280, height: 2000 },
  });
  const page = await ctx.newPage();
  try {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 45000 });
    await page.waitForTimeout(Number(opt("--wait", 1500)));
    const scrolls = Number(opt("--scroll", 0));
    for (let i = 0; i < scrolls; i++) {
      await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
      await page.waitForTimeout(1200);
    }
    const data = await page.evaluate(() => {
      document.querySelectorAll("script,style,noscript,svg").forEach((n) => n.remove());
      const text = (document.body.innerText || "").replace(/\n{3,}/g, "\n\n").trim();
      const links = [...document.querySelectorAll("a[href]")]
        .map((a) => ({ text: (a.innerText || "").trim().replace(/\s+/g, " ").slice(0, 120), href: a.href }))
        .filter((l) => l.href.startsWith("http"));
      return { title: document.title, text, links };
    });
    if (flag("--json")) {
      console.log(JSON.stringify({ url, ...data }, null, 2));
    } else {
      console.log(`# ${data.title}\n${url}\n\n${data.text}`);
      if (flag("--links")) {
        console.log("\n## Links");
        const seen = new Set();
        for (const l of data.links) if (!seen.has(l.href)) { seen.add(l.href); console.log(`- ${l.text || "(no text)"} -> ${l.href}`); }
      }
    }
  } catch (e) {
    console.error(`SCRAPE_FAILED ${url}: ${e.message.split("\n")[0]}`);
    process.exitCode = 1;
  } finally {
    await browser.close();
  }
})();
