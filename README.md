# Meme Context Finder — AI-Automated Meme, Slang & Viral Origin Encyclopedia

A complete, zero-operating-cost ($0/month) automated research, multi-source fact-checking, and static SEO publishing system for internet memes, viral slang, and cultural references.

## 1. System Architecture establishes a 100% Free-Tier Pipeline

The system combines a **Daily Scheduled Static Pipeline** (via [GitHub Actions](https://docs.github.com/billing/managing-billing-for-github-actions/about-billing-for-github-actions)) with an **On-Demand Serverless Edge Lookup API** (via [Cloudflare Pages](https://developers.cloudflare.com/pages/platform/limits/), [Cloudflare Workers](https://developers.cloudflare.com/workers/platform/limits/), and [Cloudflare Workers KV](https://developers.cloudflare.com/kv/platform/limits/)).

| Layer | Component & File | Primary Responsibility | Cost & Quota Guardrail |
| :--- | :--- | :--- | :--- |
| **1. Trend Discovery** | `pipeline/discover_and_verify.py` | Polls [Reddit r/OutOfTheLoop](https://www.reddit.com/r/OutOfTheLoop/), [Google Trends Daily RSS](https://trends.google.com/trending), and [Know Your Meme](https://knowyourmeme.com/) for emerging phrases. | Unauthenticated public JSON/RSS feeds with polite `User-Agent` headers. |
| **2. Deduplication & Verification** | `pipeline/discover_and_verify.py` | Normalizes slugs, runs fuzzy matching (`difflib` threshold `>= 0.84`), and cross-checks [Wikipedia MediaWiki API](https://www.mediawiki.org/wiki/API:Search), Reddit, Know Your Meme, and Urban Dictionary. | Blocks single-source rumors (`< 2` sources or score `< 75`) into `data/quarantine_queue.json`. |
| **3. Grounded AI Synthesis** | `pipeline/discover_and_verify.py` & `functions/api/lookup.js` | Calls [Google Gemini 2.5 Flash](https://ai.google.dev/gemini-api/docs/models) (`responseMimeType: "application/json"`) strictly grounded in retrieved evidence snippets. | 4.5s rate-limit pacing keeps calls inside the [Gemini API Free Tier](https://ai.google.dev/gemini-api/docs/rate-limits) (15 RPM / 250 RPD). |
| **4. Static SEO Generator** | `pipeline/build_site.py` | Renders indexable HTML pages (`dist/meme/<slug>/index.html`), dual [Schema.org DefinedTerm](https://schema.org/DefinedTerm) + [FAQPage](https://schema.org/FAQPage) JSON-LD, internal links, `sitemap.xml`, `rss.xml`, and `search-index.json`. | Uses 100% Python 3.11 standard library—zero third-party pip packages, `< 2s` build time. |
| **5. Edge On-Demand Search** | `functions/api/lookup.js` | Serves cached lookups from [Cloudflare Workers KV](https://developers.cloudflare.com/kv/platform/limits/) in `< 5ms`; verifies unindexed terms live and triggers a GitHub `repository_dispatch` webhook to commit a permanent SEO page. | 7-day KV TTL + 15 lookups/hour per-IP rate limit stays well inside 1,000 free KV writes/day. |
| **6. Scheduled CI/CD & Monitoring** | `.github/workflows/daily-meme-pipeline.yml` | Runs daily at `06:15 UTC`, commits updated JSON & static HTML, and automatically opens a GitHub Issue if any step fails. | Unlimited free runner minutes on public repositories ([GitHub Actions Billing](https://docs.github.com/billing/managing-billing-for-github-actions/about-billing-for-github-actions)). |

## 2. Repository Directory Structure

```text
meme-context-finder/
├── .env.example                               # Template for local environment variables
├── .github/
│   └── workflows/
│       └── daily-meme-pipeline.yml            # Scheduled cron + manual + webhook GitHub Action
├── data/
│   ├── memes.json                             # Canonical database of multi-source verified entries
│   ├── quarantine_queue.json                  # Log of blocked single-source / low-confidence claims
│   └── pipeline_status.json                   # Automated run telemetry & quota tracker
├── dist/                                      # Generated static site deployed to Cloudflare Pages
│   ├── index.html                             # Searchable encyclopedia & interactive control center
│   ├── search-index.json                      # Lightweight client-side instant search index
│   ├── sitemap.xml                            # Auto-updated XML sitemap for Google Search Console
│   ├── rss.xml                                # RSS 2.0 syndication feed
│   ├── robots.txt                             # Search crawler directives
│   ├── _headers                               # Cloudflare edge cache & security headers
│   └── meme/
│       └── <slug>/index.html                  # Individual SEO-indexed page per meme/slang phrase
├── functions/
│   └── api/
│       └── lookup.js                          # Cloudflare Pages Function (/api/lookup) + KV cache
├── pipeline/
│   ├── discover_and_verify.py                 # Automated discovery, verification & Gemini synthesis
│   └── build_site.py                          # Zero-dependency static HTML, JSON-LD & sitemap builder
├── requirements.txt                           # Zero external dependencies (Python 3.11+ stdlib)
└── wrangler.toml                              # Cloudflare Pages + Workers KV configuration
```

## 3. Free-Tier Usage Limits & Cost Analysis

Every service in this stack operates on a permanent free plan without requiring a credit card for baseline operation:

| Service | Free Tier Limit | Expected System Consumption | Potential Cost / Overage Trigger |
| :--- | :--- | :--- | :--- |
| **[Cloudflare Pages](https://developers.cloudflare.com/pages/platform/limits/)** | Unlimited static requests; 500 builds/month; 20,000 files/site; 25 MiB max file size | ~30 scheduled builds/month + ~15 on-demand builds/month (~9% of quota); ~50 KB per HTML file | **$0.00/mo**. If repository exceeds 20,000 static files (~19,990 memes), archive older memes or upgrade to Workers Paid ($5/mo for 100,000 files). |
| **[Cloudflare Workers](https://developers.cloudflare.com/workers/platform/limits/)** | 100,000 HTTP requests/day; 10 ms CPU time/invocation | Static HTML pages bypass the Worker completely (0 Worker requests). Only `/api/lookup` invokes the Worker. | **$0.00/mo**. Worker is IO-bound (`fetch` wait time does not count toward the 10 ms CPU limit). |
| **[Cloudflare Workers KV](https://developers.cloudflare.com/kv/platform/limits/)** | 100,000 reads/day; 1,000 writes to different keys/day; 1 GB storage | 1 KV read + 1 KV write per unindexed on-demand lookup; capped at 15 lookups/hour per IP | **$0.00/mo**. If >1,000 distinct new terms are queried on-demand in a single day, KV returns a 429 and falls back to static index search. |
| **[GitHub Actions](https://docs.github.com/billing/managing-billing-for-github-actions/about-billing-for-github-actions)** | Unlimited minutes for public repositories; 2,000 minutes/month for private Free accounts | ~25 seconds per daily run (~13 minutes/month total) | **$0.00/mo**. Keep the repository **public** so scheduled `cron` workflows run with unlimited free minutes. |
| **[Google Gemini API](https://ai.google.dev/gemini-api/docs/rate-limits)** | Free tier via [Google AI Studio](https://aistudio.google.com/): 15 RPM, 250 RPD (`gemini-2.5-flash`) | 1–8 requests/day during scheduled batch + cached on-demand lookups | **$0.00/mo**. Obtain the key from Google AI Studio without attaching a paid Cloud Billing account to guarantee $0 spend. |

## 4. Step-by-Step Setup & Deployment Instructions

### Step 1: Obtain Your Free Gemini API Key
1. Sign in to [Google AI Studio](https://aistudio.google.com/) and click **Get API key** -> **Create API key**.
2. Leave the project on the **Free tier** (do not attach a billing account if you want a hard $0 ceiling).
3. Copy the generated `AIzaSy...` key.

### Step 2: Push the Repository to GitHub & Configure Action Secrets
1. Create a new **Public** repository on GitHub named `meme-context-finder` and push all files from `meme-context-finder-system.zip`.
2. In your GitHub repository, navigate to **Settings** -> **Secrets and variables** -> **Actions**.
3. Under the **Secrets** tab, click **New repository secret**:
   - Name: `GEMINI_API_KEY`
   - Secret: Paste your Google AI Studio key.
4. Under the **Variables** tab, click **New repository variable**:
   - Name: `SITE_URL`
   - Value: `https://meme-context-finder.pages.dev` (or your custom domain).
5. Navigate to **Settings** -> **Actions** -> **General** -> **Workflow permissions**, and select **Read and write permissions** so the bot can commit newly verified entries and open monitoring issues if a run fails.

### Step 3: Deploy Frontend & Edge Worker to Cloudflare Pages
1. Log in to the [Cloudflare Dashboard](https://dash.cloudflare.com/) and open **Workers & Pages**.
2. Click **Create** -> **Pages** -> **Connect to Git**, and select your `meme-context-finder` GitHub repository.
3. Configure the build settings:
   - **Framework preset**: `None`
   - **Build command**: `python3 pipeline/build_site.py`
   - **Build output directory**: `dist`
4. Click **Save and Deploy**. Within ~30 seconds, your static site and `/api/lookup` Pages Function will be live at `https://<project-name>.pages.dev`.

### Step 4: Bind Cloudflare Workers KV & Edge Secrets (For On-Demand Caching)
1. In the Cloudflare Dashboard, go to **Workers & Pages** -> **KV** and click **Create a namespace** named `MEME_CACHE`.
2. Open your Cloudflare Pages project -> **Settings** -> **Bindings** -> **Add** -> **KV Namespace**:
   - **Variable name**: `MEME_CACHE`
   - **KV namespace**: Select `MEME_CACHE`.
3. Under **Settings** -> **Variables and Secrets**, add:
   - `GEMINI_API_KEY` (Encrypted Secret): Your Google AI Studio key.
   - `GITHUB_REPO` (Plaintext Variable): `your-username/meme-context-finder` (optional, enables on-demand lookups to auto-commit permanent static pages back to GitHub).
   - `GITHUB_PAT` (Encrypted Secret): A fine-grained GitHub Personal Access Token scoped to `Contents: Read and write` on this repository (optional, pairs with `GITHUB_REPO`).

## 5. End-to-End Verification & Testing Checklist

Run through these 6 verification checks to confirm that discovery, multi-source fact-checking, static SEO generation, scheduled automation, and edge caching work end to end:

- [ ] **1. Local Dry-Run & Static Build Verification**:
  Run the pipeline in dry-run mode and build the static site locally:
  ```bash
  python3 pipeline/discover_and_verify.py --dry-run
  python3 pipeline/build_site.py
  ```
  Verify that `dist/sitemap.xml`, `dist/rss.xml`, `dist/search-index.json`, and `dist/meme/skibidi-toilet/index.html` exist and contain valid HTML + JSON-LD.

- [ ] **2. Single-Term On-Demand CLI Verification**:
  Run the pipeline for a specific viral phrase with your API key set:
  ```bash
  GEMINI_API_KEY="your_key" python3 pipeline/discover_and_verify.py --term "Glazing"
  python3 pipeline/build_site.py
  ```
  Inspect `data/memes.json` and `data/pipeline_status.json` to confirm the entry was added with `confidence_score >= 75` and `>= 2` independent sources, or routed to `data/quarantine_queue.json` if uncorroborated.

- [ ] **3. Manual GitHub Actions Workflow Trigger (`workflow_dispatch`)**:
  In your GitHub repo, go to **Actions** -> **Daily Automated Meme Discovery & Static SEO Publisher** -> **Run workflow**. Enter `Fanum Tax` in the `specific_term` input and click **Run workflow**. Confirm that `meme-context-bot[bot]` commits the updated `data/memes.json` and `dist/` files within ~45 seconds.

- [ ] **4. Cloudflare Pages Automatic Redeploy Check**:
  After the GitHub Actions bot pushes a new commit, open your Cloudflare Pages dashboard and verify that a new deployment is automatically triggered and live within 1 minute.

- [ ] **5. Edge On-Demand API & KV Cache Hit Test**:
  Run two consecutive curl requests against your live Cloudflare Pages endpoint:
  ```bash
  curl -s "https://your-project.pages.dev/api/lookup?q=Crash+Out" | jq .source
  # First call output: "live-verified-synthesis"
  curl -s "https://your-project.pages.dev/api/lookup?q=Crash+Out" | jq .source
  # Second call output: "cloudflare-kv-cache"
  ```

- [ ] **6. Structured Data & SEO Indexability Check**:
  Open `https://your-project.pages.dev/sitemap.xml` to confirm all meme URLs are listed, and test any `https://your-project.pages.dev/meme/<slug>/` URL in the [Google Rich Results Test](https://search.google.com/test/rich-results) to verify the `FAQPage`, `DefinedTerm`, and `BreadcrumbList` schemas validate with zero errors.
