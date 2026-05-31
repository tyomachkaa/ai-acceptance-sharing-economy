#!/usr/bin/env python3
# =============================================================================
# 01_fetch_reddit_arcticshift.py
# Reddit baseline for the AI-acceptance project, pulled from the Arctic Shift
# research archive (a Pushshift successor) instead of live Reddit.
#
# Why: Reddit's 2026 anti-bot wall hard-blocks every anonymous .json endpoint
# (HTTP 403), which kills RedditExtractoR AND the .json-based Apify actors.
# Arctic Shift serves ARCHIVED Reddit data over a clean public API, so the
# wall is irrelevant. No token, no proxy, no cost.
#
# API: https://arctic-shift.photon-reddit.com/api/comments/search
#   params: subreddit, body (text search), limit (<=100), sort=desc, before
#
# Output: data/reddit_baseline.csv
# Pure Python stdlib (no pip installs).
# =============================================================================

import csv, json, time, urllib.parse, urllib.request
from datetime import datetime, timezone

BASE = "https://arctic-shift.photon-reddit.com/api/comments/search"
UA = "oca-research/1.0 (university text-analysis project)"
FIELDS = ["id", "subreddit", "author", "score", "created_utc",
          "link_id", "permalink", "body"]


def fetch_page(subreddit, body=None, before=None, limit=100):
    q = {"subreddit": subreddit, "limit": limit, "sort": "desc"}
    if body:
        q["body"] = body
    if before:
        q["before"] = str(int(before))
    url = BASE + "?" + urllib.parse.urlencode(q)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                data = json.loads(r.read().decode("utf-8")).get("data") or []
            return [{k: c.get(k) for k in FIELDS} for c in data]
        except Exception as e:
            if attempt == 2:
                print(f"    ! {subreddit} body={body}: {e}")
                return []
            time.sleep(1.5)
    return []


def pull(subreddit, body=None, target=300, label=""):
    out, before, guard = [], None, 0
    while True:
        pg = fetch_page(subreddit, body=body, before=before)
        if not pg:
            break
        out.extend(pg)
        cu = [c["created_utc"] for c in pg if c.get("created_utc")]
        if not cu:
            break
        before = min(cu) - 1          # step back in time
        guard += 1
        if len(out) >= target or len(pg) < 100 or guard >= 40:
            break
        time.sleep(0.4)
    print(f"  {label:30s} {len(out):4d} comments")
    return out


# ---- targets ----------------------------------------------------------------
AI_SUBS = ["ChatGPT", "OpenAI", "ClaudeAI", "CharacterAI",
           "replika", "artificial", "Bard", "perplexity_ai"]

KW_SUBS = [
    ("Turo",            ["AI", "automated", "chatbot", "bot"], "rental"),
    ("AirBnB",          ["AI", "automated", "chatbot", "bot"], "rental"),
    ("airbnb_hosts",    ["AI", "automated", "chatbot"],        "rental"),
    ("customerservice", ["AI", "chatbot", "automated"],        "customer_service"),
]

rows = []

print("=== AI-native subreddits (full pull) ===")
for s in AI_SUBS:
    for c in pull(s, target=300, label="r/" + s):
        c["platform_category"] = "ai_service"
        c["source_query"] = "subreddit"
        rows.append(c)
    time.sleep(0.4)

print("\n=== Rental / customer-service subs (AI keyword search) ===")
for sub, kws, cat in KW_SUBS:
    for k in kws:
        for c in pull(sub, body=k, target=150, label=f"r/{sub} body='{k}'"):
            c["platform_category"] = cat
            c["source_query"] = k
            rows.append(c)
        time.sleep(0.4)

# ---- clean ------------------------------------------------------------------
print(f"\nRaw pulled: {len(rows)} comments")
seen, clean = set(), []
for c in rows:
    b = (c.get("body") or "").strip()
    cid = c.get("id")
    if not b or b in ("[deleted]", "[removed]") or len(b) < 20:
        continue
    if cid in seen:
        continue
    seen.add(cid)
    cu = c.get("created_utc")
    c["date"] = (datetime.fromtimestamp(cu, tz=timezone.utc).strftime("%Y-%m-%d")
                 if cu else "")
    clean.append(c)

# ---- write ------------------------------------------------------------------
out_cols = FIELDS + ["platform_category", "source_query", "date"]
with open("data/reddit_baseline.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=out_cols, extrasaction="ignore")
    w.writeheader()
    w.writerows(clean)

# ---- report -----------------------------------------------------------------
from collections import Counter
cats = Counter(c["platform_category"] for c in clean)
subs = Counter(c["subreddit"] for c in clean)
dates = sorted(c["date"] for c in clean if c["date"])
print(f"\nFinal: {len(clean)} unique comments | {len(subs)} subreddits"
      f" | {dates[0]} to {dates[-1]}")
print("\nBy platform_category:")
for k, v in cats.most_common():
    print(f"  {k:18s} {v}")
print("\nTop subreddits:")
for k, v in subs.most_common(15):
    print(f"  r/{k:16s} {v}")
print("\nWrote data/reddit_baseline.csv")
