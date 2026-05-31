# Project Handoff — Status & Next Steps

**Last updated:** May 31, 2026
**Repo:** https://github.com/tyomachkaa/ai-acceptance-sharing-economy

This is the short internal status note. The full overview for outsiders lives in [`README.md`](README.md) and [`outputs/coaching_overview.pdf`](outputs/coaching_overview.pdf).

---

## TL;DR for the team

- **Data collection: done** — Reddit and Trustpilot both scraped, cleaned, themed, ready for analysis.
- **Analysis: not started** — exploratory only. Word freq, ratings, sentiment timeline, comparison cloud already exist as preliminary figures.
- **Professor's framing (from last coaching session):** **Reddit = baseline discussion corpus, Trustpilot = verification layer.** Trustpilot's star ratings act as ground-truth labels we use to validate the sentiment lexicon we apply to Reddit.
- **No open decisions blocking the next sprint.** Decisions #1–#3 from the previous handoff are resolved (see below). Move straight into analysis.

---

## What we have right now (numbers from today)

| File | Rows | Notes |
|---|---|---|
| `data/reddit_targeted.csv` | 1,009 | v2 raw subreddit-targeted scrape (source for cleaning) |
| **`data/reddit_clean.csv`** | **314** | **v2 cleaned + themed — USE THIS** |
| `data/trustpilot_reviews.csv` | 3,912 | 7 platforms: Turo (1482), Fat Llama (835), RVshare (773), Outdoorsy (751), Lensrentals (35), Getaround (31), KitSplit (5) |
| `data/trustpilot_raw/` | 7 files | Per-platform Apify downloads, before merge |

**Time spans:** Reddit 2012–2026, Trustpilot 2019–2026.
**Trustpilot labels:** 1–5 star ratings = ground-truth sentiment (no lexicon needed).
**Reddit `reddit_clean.csv`:** has a `theme` column = `sharing_economy` (168) | `ai_tech` (146).

---

## What changed since the last handoff

### 1. Reddit corpus cleaned → `data/reddit_clean.csv`

Script: `05_clean_reddit.R`.

What it does:
- Reads `reddit_targeted.csv` (1,009 raw).
- Drops 2 subreddits dominated by off-topic creative-AI debates: **r/Filmmakers**, **r/Entrepreneur**. These two subs alone held the 3 viral threads that made up ~67% of the raw corpus ("Sir Roger Deakins", "they don't like movies", "Boring Business").
- Adds a `theme` column to every remaining comment: `sharing_economy` (rental/host/gear subs) | `ai_tech` (AI/privacy/agent subs).
- Result: **314 comments, 17 subreddits, 38 threads, ~47/53 theme balance**.

Subreddit composition (cleaned):

```
sharing_economy (168):
  photography 76 · GoRVing 38 · AirBnB 22 · dji 13 · turo 9
  cinematography 5 · + small tail (AirBnBHosts, EventProduction,
  airbnb_hosts, livesound, vrbo, all n=1)

ai_tech (146):
  ChatGPT 81 · privacy 56 · artificial 5 · technology 2
  OpenAI 1 · SaaS 1
```

### 2. OAuth deep-scrape attempt → moved to `legacy/`

We tried to do a much bigger Reddit scrape (~3,000–8,000 comments) via direct OAuth requests because:
- Reddit's **anti-bot wall** now hard-blocks anonymous JSON endpoints (every request from this IP returns HTTP 403 + 189KB of HTML). The previous `RedditExtractoR` runs worked because Reddit was less strict at the time; that door is now closed.
- The OAuth path requires creating a `script` app at `reddit.com/prefs/apps`. The form was a hard wall (reCAPTCHA/validator issues), so we pivoted to **Path B: clean what we have**.

The OAuth scripts are preserved in `legacy/`:
- `legacy/scrape_reddit_oauth_attempt.R` — the deep-scrape via `oauth.reddit.com` (38 subs × ~340 keyword pairs × 2 sort orders).
- `legacy/setup_reddit_oauth_test.R` — the 5-second OAuth credential test.

If anyone on the team can complete the Reddit app form successfully later, those scripts will work — drop the env vars into `.Renviron`, run the test, then run the deep scrape.

---

## What's been built so far

| File | Purpose | Status |
|---|---|---|
| `01_scrape_reddit.R` | Subreddit-targeted Reddit scrape (v2) | ✅ working |
| `02_merge_trustpilot.R` | Combine Apify Trustpilot CSVs | ✅ working |
| `03_preliminary_analysis.R` | Quick exploratory pass + figures | ✅ working |
| **`05_clean_reddit.R`** | **Drop off-topic subs + theme tagging → reddit_clean.csv** | **✅ working** |
| `coaching_overview.Rmd` | Progress report for coaching session | ✅ knit, 5 figures; now reads from `reddit_clean.csv` so a re-knit reflects the 314-comment cleaned corpus |
| `outputs/coaching_overview.pdf` | Main deliverable for coach | ✅ |
| `outputs/reddit_scrape_comparison.pdf` | Methodology one-pager (v1 vs v2) — PDF kept, source Rmd removed during cleanup | ✅ |
| `figures/` | 4 PNGs from the prelim pass | ✅ |

Note: the existing `outputs/coaching_overview.pdf` was knit against the older 697-comment file. The source `.Rmd` now reads `data/reddit_clean.csv`, so a re-knit reproduces it with the cleaned 314-comment numbers — that's a 1-line knit and refreshes all 5 figures + the stats.

---

## Caveats to flag in the final report

- **One dominant thread:** the cleaned corpus is still 26% one thread ("Ultimate Guide: 86 ChatGPT Plugins", r/ChatGPT, 81 comments). It's the densest on-topic AI thread we have, so it stayed — but AI-side LDA topics will lean toward "AI tools/plugins" language because of it.
- **Photography sub mixes gear-rental and pure-gear-talk threads** (Sigma vs Canon, Milky Way photography, etc.). Preprocessing + topic modelling will absorb these into their own cluster, which you can keep as the "gear-talk" vocabulary fingerprint or drop in LDA cleanup.
- **38 threads is small for LDA** — realistic ceiling is **3–4 topics per theme**, not 5+.
- **Trustpilot reviews skew positive** (typical opt-in bias) → downsample for balanced classification.
- **Equipment-rental platforms (KitSplit n=5, Lensrentals n=35)** are too small for confident per-platform claims.
- **"Trust"** appears mostly *implicitly* in both corpora — measure it via topics and sentiment, not keyword counts.
- English-only.

---

## Decisions needed (this week)

**None blocking.** Previous decisions resolved:

| Decision | Resolution |
|---|---|
| **1. Reddit corpus: rebalance or live with it?** | Resolved — cleaned to 314 comments via `05_clean_reddit.R`. Themes are 47/53 balanced. |
| **2. Framing for the analysis** | Resolved (per professor): **Reddit = baseline, Trustpilot = verification.** Use Trustpilot stars to validate the AFINN/NRC scores we compute on Reddit. |
| **3. R `text` package?** | Still optional — high effort, high differentiator. Person C's call. |

---

## Suggested task split (3-person team)

> Adjust to actual team size.

### Person A — Data / preprocessing / topic modelling
- ~~Resolve Decision #1 (rebalance Reddit)~~ ✅ done
- Build `06_preprocess.R`: lemmatise, stopword removal, 1g + 2g tokenisation (both sources, reading from `reddit_clean.csv` and `trustpilot_reviews.csv`)
- Build `07_lda.R`: **3–4 topics per theme** (cap at 4 given small thread count), 1-gram and bi-gram, seeded LDA
- Suggested packages: `tidytext`, `quanteda`, `textstem`, `seededlda`, `topicmodels`

### Person B — Visualisation / writing / report
- Word frequency bar plots (top 10 per theme) — required by the brief
- Comparison + commonality word clouds (1g and 2g) — required
- Co-occurrence networks (`widyr::pairwise_count` + `ggraph`) — required
- Sentiment plot (both themes on one graph, plus Trustpilot stars overlay) — required
- Compile final report Rmd (build on `coaching_overview.Rmd`, refresh stats from `reddit_clean.csv`)

### Person C — Sentiment / embeddings / synthesis
- AFINN + NRC sentiment on Reddit, **validate against Trustpilot stars** (the convergent-validity check the professor flagged)
- NRC 8-emotion profile per source
- GloVe embeddings via `text2vec`: neighbours of "trust", "AI", "host"
- Map findings to trust frameworks (Mayer 1995 — ability/benevolence/integrity; TAM)
- Optional: R `text` package work (Decision #3)
- Draft **AI-agent Design Cards** (8 concrete recommendations backed by data)

---

## How to set up locally (for a new teammate)

```bash
git clone https://github.com/tyomachkaa/ai-acceptance-sharing-economy.git
cd ai-acceptance-sharing-economy
open coaching_overview.Rmd        # opens in RStudio
```

In R, once:

```r
install.packages(c(
  "RedditExtractoR", "dplyr", "tidyr", "stringr", "purrr",
  "tidytext", "ggplot2", "lubridate", "scales",
  "wordcloud", "RColorBrewer", "rmarkdown", "knitr",
  "quanteda", "textstem", "seededlda", "topicmodels",
  "syuzhet", "widyr", "ggraph", "igraph", "text2vec"
))
```

Then knit `coaching_overview.Rmd` to verify the environment works.

---

## Open the project in two clicks

- **Repo:** https://github.com/tyomachkaa/ai-acceptance-sharing-economy
- **Main progress PDF:** [outputs/coaching_overview.pdf](outputs/coaching_overview.pdf)
- **Methodology note:** [outputs/reddit_scrape_comparison.pdf](outputs/reddit_scrape_comparison.pdf)
