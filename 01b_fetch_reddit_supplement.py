#!/usr/bin/env python3
# Supplement for 01_fetch_reddit_arcticshift.py: recovers the (subreddit,keyword)
# pulls that got rate-limited (HTTP 422 under burst) on the first run, using
# longer delays + exponential backoff. Appends new unique comments to
# data/reddit_baseline.csv.
import csv, json, time, urllib.parse, urllib.request

BASE = "https://arctic-shift.photon-reddit.com/api/comments/search"
UA = "oca-research/1.0 (university text-analysis project)"
FIELDS = ["id", "subreddit", "author", "score", "created_utc",
          "link_id", "permalink", "body"]
CSV = "data/reddit_baseline.csv"


def fetch_page(subreddit, body=None, before=None, limit=100):
    q = {"subreddit": subreddit, "limit": limit, "sort": "desc"}
    if body:
        q["body"] = body
    if before:
        q["before"] = str(int(before))
    url = BASE + "?" + urllib.parse.urlencode(q)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    delay = 3
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                return [{k: c.get(k) for k in FIELDS}
                        for c in (json.loads(r.read().decode("utf-8")).get("data") or [])]
        except urllib.error.HTTPError as e:
            if e.code in (422, 429) and attempt < 4:
                time.sleep(delay); delay *= 2; continue   # back off + retry
            print(f"    ! {subreddit} body={body}: HTTP {e.code}")
            return None     # None = give up on this term
        except Exception as e:
            if attempt < 4:
                time.sleep(delay); delay *= 2; continue
            print(f"    ! {subreddit} body={body}: {e}")
            return None
    return None


def pull(subreddit, body, target=150, label=""):
    out, before, guard = [], None, 0
    while True:
        pg = fetch_page(subreddit, body=body, before=before)
        if pg is None:               # hard failure / persistent 422
            break
        if not pg:
            break
        out.extend(pg)
        cu = [c["created_utc"] for c in pg if c.get("created_utc")]
        if not cu:
            break
        before = min(cu) - 1
        guard += 1
        if len(out) >= target or len(pg) < 100 or guard >= 30:
            break
        time.sleep(1.2)              # gentle
    print(f"  {label:34s} {len(out):4d} comments")
    return out


MISSING = [
    ("airbnb_hosts",    ["AI", "automated"],        "rental"),
    ("customerservice", ["AI", "automated", "bot"], "customer_service"),
    ("Turo",            ["app"],                    "rental"),   # extra rental AI/app signal
    ("AirBnB",          ["bot"],                    "rental"),
]

# load existing
with open(CSV, encoding="utf-8") as f:
    existing = list(csv.DictReader(f))
seen = {r["id"] for r in existing}
print(f"Existing baseline: {len(existing)} comments")

new = []
for sub, kws, cat in MISSING:
    for k in kws:
        for c in pull(sub, k, label=f"r/{sub} body='{k}'"):
            cid = c.get("id")
            b = (c.get("body") or "").strip()
            if not cid or cid in seen or not b or b in ("[deleted]", "[removed]") or len(b) < 20:
                continue
            seen.add(cid)
            import datetime
            cu = c.get("created_utc")
            c["date"] = (datetime.datetime.fromtimestamp(
                cu, tz=datetime.timezone.utc).strftime("%Y-%m-%d") if cu else "")
            c["platform_category"] = cat
            c["source_query"] = k
            new.append(c)
        time.sleep(1.2)

print(f"\nNew unique comments added: {len(new)}")

out_cols = FIELDS + ["platform_category", "source_query", "date"]
with open(CSV, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=out_cols, extrasaction="ignore")
    w.writeheader()
    w.writerows(existing + new)

from collections import Counter
allrows = existing + new
print(f"\nUpdated baseline: {len(allrows)} comments")
print("By platform_category:")
for k, v in Counter(r["platform_category"] for r in allrows).most_common():
    print(f"  {k:18s} {v}")
print("\nWrote", CSV)
