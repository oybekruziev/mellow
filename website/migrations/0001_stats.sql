-- Privacy-friendly visit and download counts for the admin page (no cookies, no IPs).
-- `id` is a hash of IP + user agent with a salt that changes every day, so the same person
-- counts once per day and can't be recognised across days.

-- Totals per day (Asia/Tashkent): every page view and every started DMG download.
CREATE TABLE IF NOT EXISTS daily (
  day TEXT PRIMARY KEY,
  pageviews INTEGER NOT NULL DEFAULT 0,
  downloads INTEGER NOT NULL DEFAULT 0
);

-- One row per visitor per day.
CREATE TABLE IF NOT EXISTS visitors (
  day TEXT NOT NULL,
  id TEXT NOT NULL,
  country TEXT,
  referrer TEXT,
  PRIMARY KEY (day, id)
);

-- One row per person who downloaded per day.
CREATE TABLE IF NOT EXISTS downloaders (
  day TEXT NOT NULL,
  id TEXT NOT NULL,
  country TEXT,
  PRIMARY KEY (day, id)
);
