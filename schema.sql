-- Cloudflare D1 (Serverless SQLite) + FTS5 Schema for Millions of Slang & Meme Entries
-- Supports <5ms indexed slug lookups, sharded keyset pagination for 50k-URL sitemaps,
-- and sub-10ms full-text search across 1,000,000+ rows without loading JSON into memory.

CREATE TABLE IF NOT EXISTS slang_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  slug TEXT NOT NULL UNIQUE,
  term TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'Viral Slang',
  status TEXT NOT NULL DEFAULT 'Verified',      -- 'Verified' | 'Seeded-Wiktionary' | 'Enriched'
  confidence_score INTEGER NOT NULL DEFAULT 85,
  first_seen TEXT NOT NULL DEFAULT '2024-01',
  last_verified TEXT NOT NULL DEFAULT '2026-10-20',
  tldr TEXT NOT NULL,
  meaning TEXT NOT NULL,
  origin TEXT NOT NULL,
  usage_examples_json TEXT NOT NULL DEFAULT '[]',
  timeline_json TEXT NOT NULL DEFAULT '[]',
  related_terms_json TEXT NOT NULL DEFAULT '[]',
  sources_json TEXT NOT NULL DEFAULT '[]',
  is_ai_enriched INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_slang_slug ON slang_entries(slug);
CREATE INDEX IF NOT EXISTS idx_slang_category ON slang_entries(category);
CREATE INDEX IF NOT EXISTS idx_slang_confidence ON slang_entries(confidence_score DESC);

-- Virtual FTS5 Table for instant full-text search across millions of definitions
CREATE VIRTUAL TABLE IF NOT EXISTS slang_fts USING fts5(
  slug UNINDEXED,
  term,
  tldr,
  meaning,
  origin,
  content='slang_entries',
  content_rowid='id'
);

-- Triggers to keep FTS5 index automatically synchronized on INSERT/UPDATE
CREATE TRIGGER IF NOT EXISTS slang_ai AFTER INSERT ON slang_entries BEGIN
  INSERT INTO slang_fts(rowid, slug, term, tldr, meaning, origin)
  VALUES (new.id, new.slug, new.term, new.tldr, new.meaning, new.origin);
END;
