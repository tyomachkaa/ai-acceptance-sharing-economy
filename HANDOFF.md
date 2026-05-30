# Project Handoff — Status & Next Steps

**Last updated:** May 28, 2026
**Repo:** https://github.com/tyomachkaa/ai-acceptance-sharing-economy

This is the short internal status note. The full overview for outsiders lives in [`README.md`](README.md) and [`outputs/coaching_overview.pdf`](outputs/coaching_overview.pdf).

---

## TL;DR for the team

- **Data collection: done** — Reddit and Trustpilot are both scraped, cleaned-ish, and saved.
- **Analysis: not started** — exploratory only. Word freq, ratings, sentiment timeline, comparison cloud already exist as preliminary figures.
- **One decision needed from the team this week** — see [Decisions](#decisions-needed) below.

---

## What we have right now (numbers from today)

| File | Rows | Notes |
|---|---|---|
| `data/reddit_all.csv` | 14,090 | INITIAL keyword scrape — **off-topic, kept only as baseline** |
| `data/reddit_targeted.csv` | 1,009 | Revised scrape, raw (every comment from on-topic threads) |
| `data/reddit_targeted_balanced.csv` | 697 | Same as above but capped at 120 comments/thread |
| `data/trustpilot_reviews.csv` | 3,912 | 7 platforms: Turo (1482), Fat Llama (835), RVshare (773), Outdoorsy (751), Lensrentals (35), Getaround (31), KitSplit (5) |
| `data/trustpilot_raw/` | 7 files | Per-platform Apify downloads, before merge |

**Time spans:** Reddit 2012–2026, Trustpilot 2019–2026.
**Trustpilot labels:** 1–5 star ratings = ground-truth sentiment (no lexicon needed).

---

## What changed in the latest Reddit scrape

The script `01_scrape_reddit.R` was upgraded:

| Lever | Before | Now |
|---|---|---|
| Search queries (subreddit × keyword) | 28 | **47** (added vrbo, RVing, GoRVing, AskPhotography, OpenAI, singularity, …) |
| Threads per search | 25 | 30 |
| Min comments/thread to keep | ≥ 10 | ≥ 6 |
| Max threads fetched | 200 | 400 |
| Per-thread comment cap | 50 (manual post-hoc) | **120 (built into script)** |
| Outputs | RAW only | RAW **+ BALANCED** (cap applied automatically) |

The script now writes both files in one go and tags each comment with a `theme` column (`sharing_economy` or `ai_creative_tech`).

### Honest result of the upgrade

- Total bigger: **697 vs 483** comments in the balanced file ✅
- **But:** sharing-economy share dropped dramatically (285 → 73 comments) ⚠️
- Reason: bigger cap (50 → 120) let viral AI-discussion threads in r/Filmmakers and r/Entrepreneur dominate; some sharing-economy subreddits returned fewer results this time around (Reddit relevance sort is non-deterministic).

### Current subreddit composition (balanced)

```
Filmmakers      258   ← AI in creative industries (viral)
Entrepreneur    125   ← AI agents in business
ChatGPT          81
photography      76
privacy          56
GoRVing          38
AirBnB           22
dji              13
turo              9
artificial        5
cinematography    5
technology        2
```

---

## What's been built so far

| File | Purpose | Status |
|---|---|---|
| `01_scrape_reddit.R` | Subreddit-targeted Reddit scrape | ✅ working |
| `02_merge_trustpilot.R` | Combine Apify CSVs into one Trustpilot file | ✅ working |
| `03_preliminary_analysis.R` | Quick exploratory pass (top words, ratings, figures) | ✅ working |
| `04_compare_versions.R` | v1 vs v2 Reddit methodology comparison | ✅ working |
| `coaching_overview.Rmd` | Progress report for coaching session | ✅ knit, 5 figures |
| `reddit_scrape_comparison.Rmd` | Methodology note (v1 vs v2) | ✅ knit |
| `outputs/coaching_overview.pdf` | Main deliverable for coach | ✅ |
| `outputs/reddit_scrape_comparison.pdf` | Methodology one-pager | ✅ |
| `figures/` | 4 PNGs from the prelim pass | ✅ |

---

## Decisions needed (this week)

These are the **only** open questions blocking the next analysis sprint. Resolve them with the team in a 15-min call.

### 1. Reddit corpus: rebalance or live with it?

The current balanced file has too few sharing-economy comments (73). Three options:

| Option | What | Pros | Cons |
|---|---|---|---|
| **A** Lower cap back to 50 | Rerun the save block of `01_scrape_reddit.R` with `cap_per_thread <- 50` | smaller corpus but evenly-balanced themes | shrinks total to ~450 |
| **B** Drop noisy subreddits | Remove Filmmakers/Entrepreneur/photography from `targets` and re-scrape | keeps cap high, refocuses on rentals | another 30-min scrape |
| **C** Keep as-is | Use 697 with the imbalance noted | uses what we have | analysis gets pulled toward "creative AI anxiety", away from rentals |

**Recommendation:** Option **A** (cheapest, no rescrape). Just rerun the save section.

### 2. Framing for the analysis

Should the comparison be:
- **(a)** Cross-source / cross-platform (Reddit vs Trustpilot, platform-vs-platform) — our current direction, *or*
- **(b)** Positive-vs-negative classification (1-2★ vs 4-5★ on Trustpilot)?

This decides how we set up LDA and labelling. Confirm with the professor in the coaching session.

### 3. Should the R `text` package be used (LLM sentence embeddings + Q&A)?

The brief mentions it. Almost no group uses it. It needs Python + HF transformers under the hood — non-trivial setup (~30 min). Big differentiator if it works.

---

## Suggested task split (3-person team)

> Adjust to your actual team size and skills.

### Person A — Data / preprocessing / topic modelling
- Resolve Decision #1 (rebalance Reddit)
- Build `05_preprocess.R`: lemmatise, stopword removal, 1g + 2g tokenisation (both sources)
- Build `06_lda.R`: 3–5 topics per class, 1-gram and bi-gram, seeded LDA
- Suggested packages: `tidytext`, `quanteda`, `textstem`, `seededlda`, `topicmodels`

### Person B — Visualisation / writing / report
- Word frequency bar plots (top 10 per class) — required by the brief
- Comparison + commonality word clouds (1g and 2g) — required
- Co-occurrence networks (`widyr::pairwise_count` + `ggraph`) — required
- Sentiment plot (both classes on one graph) — required
- Compile the final report Rmd (build on `coaching_overview.Rmd`)

### Person C — Sentiment / embeddings / synthesis
- AFINN + NRC sentiment on Reddit, validate against Trustpilot stars (triangulation)
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

## Limitations to mention up-front in the report

- Trustpilot reviews skew positive (typical opt-in bias) → downsample for balanced classification.
- Equipment-rental platforms (KitSplit n=5, Lensrentals n=35) are too small for confident per-platform claims.
- "Trust" appears mostly *implicitly* in both corpora — we measure it via topics and sentiment, not keyword counts.
- English-only.
- Reddit comments are kept from on-topic *threads* — some off-topic chatter rides along, which preprocessing + topic modelling should absorb.

---

## Open the project in two clicks

- **Repo:** https://github.com/tyomachkaa/ai-acceptance-sharing-economy
- **Main progress PDF:** [outputs/coaching_overview.pdf](outputs/coaching_overview.pdf)
- **Methodology note:** [outputs/reddit_scrape_comparison.pdf](outputs/reddit_scrape_comparison.pdf)
