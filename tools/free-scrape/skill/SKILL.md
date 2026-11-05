---
name: free-scrape
description: Free, unlimited replacement for Firecrawl. Use whenever you need to read, scrape or crawl a web page (JS-heavy pages, lazy-loading lists, YouTube channel tabs, campaign boards) in any repository. Never use Firecrawl, its credits run out.
---

# free-scrape

Renders a page in local headless Chromium (Playwright) and prints clean text and links, like Firecrawl's scrape. No account, no API key, no credits.

```bash
free-scrape <url>                    # page text
free-scrape <url> --scroll 8 --links # load lazy lists, then list every link
free-scrape <url> --json             # {url,title,text,links}
free-scrape <url> --wait 4000        # extra wait for slow pages
```

## Rules
- Prefer this over any Firecrawl tool. Use the built-in WebSearch to find URLs, then `free-scrape` to read them.
- Only hosts the cloud environment's network allows will load. A failure prints `SCRAPE_FAILED <url>: net::ERR_TUNNEL_CONNECTION_FAILED` when the host is blocked. Then try WebFetch, or tell the user which host to allow in the environment settings.
- Respect site terms: read public pages only, no logins, no bypassing paywalls or bot checks, keep request volume low.
