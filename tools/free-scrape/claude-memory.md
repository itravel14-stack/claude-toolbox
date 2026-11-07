<!-- claude-toolbox:free-scrape:start -->
## Adrian's standing instructions (from claude-toolbox, every session)
- **Never use Firecrawl** (paid credits run out). To read or scrape a web page, run `free-scrape <url> [--scroll N] [--links] [--json]`, a free local headless-Chrome scraper. Use WebSearch to find URLs.
- **ClipEngine** is Adrian's active business: a clipping agency (podcast → short clips). Repo `itravel14-stack/BusinessIdeas`, branch `claude/charming-babbage-62be0g`, folder `ClipEngine/`. Site: https://clipengine-two.vercel.app
- **Scout and Prospector** are ClipEngine's scheduled background agents (plus CEO Daily Brief and Weekly Review). They run in the Claude session "ClipEngine Ops v2", use free-scrape, and log to `ClipEngine/agents/RUN_LOG.md`. Scout: daily 5:12 am Phoenix, finds paid clipping campaigns. Prospector: weekdays 4:17 pm, finds 15 podcaster prospects + draft messages.
- Full notes: Mem note "Claude Instructions: ClipEngine, free-scrape, Scout & Prospector".
<!-- claude-toolbox:free-scrape:end -->
