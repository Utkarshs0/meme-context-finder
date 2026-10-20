#!/usr/bin/env bash
# ==============================================================================
# Meme Context Finder — One-Command Turnkey Launcher (launch.sh)
# Automatically provisions Cloudflare D1 (SQLite + FTS5), Workers KV (MEME_CACHE),
# seeds initial verified memes & slang, builds the site, and deploys to Cloudflare Pages!
# ==============================================================================
set -euo pipefail

echo "========================================================"
echo "🚀 Meme Context Finder — Automated Live Website Launcher"
echo "========================================================"

if ! command -v npx >/dev/null 2>&1; then
  echo "❌ Error: Node.js / npx is required. Install Node.js (https://nodejs.org) and re-run ./launch.sh"
  exit 1
fi

echo "1️⃣  Building static SEO pages, JSON-LD schemas, and sitemap..."
python3 pipeline/build_site.py

echo "2️⃣  Checking Cloudflare Wrangler authentication..."
npx --yes wrangler whoami || npx --yes wrangler login

echo "3️⃣  Provisioning Cloudflare D1 Database ('meme-dictionary')..."
D1_OUT=$(npx --yes wrangler d1 create meme-dictionary 2>&1 || true)
D1_ID=$(echo "$D1_OUT" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -n 1 || true)

if [ -n "$D1_ID" ]; then
  echo "   ✅ Created D1 Database ID: $D1_ID"
  sed -i.bak "s/REPLACE_WITH_YOUR_CLOUDFLARE_D1_DATABASE_ID/$D1_ID/g" wrangler.toml && rm -f wrangler.toml.bak
else
  echo "   ℹ️  D1 Database 'meme-dictionary' already exists or continuing with wrangler.toml config."
fi

echo "4️⃣  Applying SQLite + FTS5 Schema & Seeding Initial Verified Entries into D1..."
npx --yes wrangler d1 execute meme-dictionary --file=schema.sql --remote || true
npx --yes wrangler d1 execute meme-dictionary --file=data/initial_seed.sql --remote || true

echo "5️⃣  Provisioning Cloudflare Workers KV Namespace ('MEME_CACHE')..."
KV_OUT=$(npx --yes wrangler kv namespace create MEME_CACHE 2>&1 || true)
KV_ID=$(echo "$KV_OUT" | grep -oE '[0-9a-f]{32}' | head -n 1 || true)

if [ -n "$KV_ID" ]; then
  echo "   ✅ Created KV Namespace ID: $KV_ID"
  sed -i.bak "s/REPLACE_WITH_YOUR_CLOUDFLARE_KV_NAMESPACE_ID/$KV_ID/g" wrangler.toml && rm -f wrangler.toml.bak
fi

echo "6️⃣  Deploying Live Website + Edge Functions to Cloudflare Pages..."
npx --yes wrangler pages project create meme-context-finder --production-branch=main 2>/dev/null || true
npx --yes wrangler pages deploy dist --project-name=meme-context-finder

echo "========================================================"
echo "🎉 LIVE! Your Meme Context Finder website is now deployed!"
echo "👉 Next: Add GEMINI_API_KEY in Cloudflare Dashboard -> Pages -> meme-context-finder -> Settings -> Variables"
echo "========================================================"
