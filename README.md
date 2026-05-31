# AI Acceptance in the Sharing Economy

> A text-analysis project on **how users perceive AI agents on peer-to-peer rental platforms** (Turo, Airbnb, Fat Llama, RVshare, Outdoorsy, KitSplit, …) — and what builds or erodes their trust.

Final project for **Online Content Analysis** at WU Vienna.
We collect two complementary text sources, compare them, and turn the findings into design recommendations for AI agents in rental marketplaces.

---

## TL;DR

| | What we did | Outcome |
|---|---|---|
| **Sources** | Reddit (discussion baseline) + Trustpilot (verification via star ratings) | 2 self-scraped corpora |
| **Reddit** | Topic-targeted scrape → cleaned + themed | **314 on-topic comments** across 17 subreddits, balanced 47/53 between `sharing_economy` and `ai_tech` |
| **Trustpilot** | 7 sharing-economy platforms via Apify | 3,912 reviews with 1-5★ ground-truth labels |
| **Headline finding** | Trust varies sharply by *rental type* | Car/RV sharing 3.7-4.6★ vs equipment rental 1-3★ |
| **Methodology note** | v1 keyword scrape was off-topic; v2 subreddit-scoped; v2-cleaned drops viral-thread noise | progressively more relevant corpus |

Read the full progress report: [outputs/coaching_overview.pdf](outputs/coaching_overview.pdf).
Methodology fix in detail: [outputs/reddit_scrape_comparison.pdf](outputs/reddit_scrape_comparison.pdf).

---

## Repository layout

```
.
├── README.md                            <- this file
├── LICENSE                              <- MIT
├── .gitignore
│
├── 01_scrape_reddit.R                   <- run 1st: subreddit-targeted Reddit pull
├── 02_merge_trustpilot.R                <- run 2nd: combine Apify Trustpilot CSVs
├── 03_preliminary_analysis.R            <- quick exploratory pass + figures
├── 05_clean_reddit.R                    <- drop off-topic subs + tag theme  → reddit_clean.csv
│
├── coaching_overview.Rmd                <- main progress report
│
├── data/
│   ├── reddit_targeted.csv              <- v2 raw (1,009 rows, source for cleaning)
│   ├── reddit_clean.csv                 <- v2 cleaned + themed (USE THIS — 314 rows)
│   ├── trustpilot_reviews.csv           <- merged Trustpilot reviews (3,912 rows)
│   └── trustpilot_raw/                  <- per-platform Apify CSVs (inputs)
│
├── outputs/                             <- knitted PDFs
│   ├── coaching_overview.pdf
│   └── reddit_scrape_comparison.pdf     <- methodology one-pager (v1 vs v2)
│
├── figures/                             <- generated PNGs
│
└── legacy/                              <- old / failed attempts kept for transparency
    ├── scraping_data_v1.R               <- the original off-topic keyword scrape
    ├── scrape_trustpilot_api_attempt.R  <- failed Apify API (free-tier capped)
    ├── scrape_trustpilot_saswave_attempt.R
    ├── scrape_reddit_oauth_attempt.R    <- OAuth deep-scrape (Reddit form blocked)
    └── setup_reddit_oauth_test.R
```

---

## Research question

> **How do users perceive AI agents on peer-to-peer rental platforms, and what drives trust — across platform types and across community discussion (Reddit) vs. paying-customer experience (Trustpilot)?**

The sharing economy increasingly embeds AI for matching, messaging, pricing and damage assessment. We study how users *react* to that automation and which design factors earn (or lose) their trust.

---

## Data sources

### Reddit (community discussion — the baseline)

- Tool: [`RedditExtractoR`](https://cran.r-project.org/package=RedditExtractoR) (R, public Reddit API)
- Strategy: **subreddit-scoped keyword search** across 30+ communities (r/Turo, r/AirBnB, r/photography, r/drones, r/privacy, r/ChatGPT, …)
- Post-processing: `05_clean_reddit.R` drops 2 off-topic subreddits (r/Filmmakers, r/Entrepreneur — they held the 3 viral threads that made up ~67% of the raw scrape) and tags each remaining comment with a `theme` column (`sharing_economy` | `ai_tech`).
- **Output file to use:** `data/reddit_clean.csv` (314 rows, 17 subreddits, 47/53 theme balance)
- See `01_scrape_reddit.R` (collection) and `05_clean_reddit.R` (cleaning)

> **Reddit anti-bot wall (2026):** Reddit now hard-blocks anonymous JSON endpoints from most non-residential IPs (HTTP 403 + bot-wall HTML on every request). The v2 scrape worked when those rules were laxer. A later attempt to re-scrape via OAuth is preserved in `legacy/scrape_reddit_oauth_attempt.R` — it works in principle but requires a Reddit `script` app, which we did not register.

### Trustpilot (paying-customer reviews)

- Tool: [Apify](https://apify.com) actor `casper11515/trustpilot-reviews-scraper` (run via Apify web UI)
- Platforms scraped: Turo, Fat Llama, RVshare, Outdoorsy, Lensrentals, Getaround, KitSplit
- Each result CSV downloaded into `data/trustpilot_raw/`, then merged with `02_merge_trustpilot.R`
- Output: `data/trustpilot_reviews.csv` — 3,912 reviews, 1-5★ ratings = real sentiment ground truth

### Why two sources

Per the professor's framing: **Reddit = baseline discussion corpus, Trustpilot = verification layer.**

- Reddit captures *deliberation* — host/renter disputes, complaints, AI debates.
- Trustpilot captures *post-transaction satisfaction* with **1–5★ ground-truth labels** — no lexicon needed.
- We use Trustpilot stars to *validate* the AFINN/NRC sentiment we compute on Reddit (convergent validity check). Trustpilot is the heavier corpus and the more analytically valuable one; Reddit is the discussion layer that answers "what do users *talk about* around AI and rentals."

---

## How to reproduce

### 1. Install R packages

```r
install.packages(c(
  "RedditExtractoR", "dplyr", "tidyr", "stringr", "purrr",
  "tidytext", "ggplot2", "lubridate", "scales",
  "wordcloud", "RColorBrewer",
  "rmarkdown", "knitr"
))
```

### 2. Re-scrape Reddit (optional — data is checked in)

```r
setwd("/path/to/Final Project")
source("01_scrape_reddit.R")     # raw scrape  → data/reddit_targeted.csv + _balanced.csv
source("05_clean_reddit.R")      # clean+theme → data/reddit_clean.csv  (USE THIS)
```

Wall-clock: ~30-45 min for `01_scrape_reddit.R`, ~5 sec for `05_clean_reddit.R`.

> ⚠️ As of mid-2026 Reddit hard-blocks anonymous JSON requests from most IPs. A fresh run of `01_scrape_reddit.R` may return HTTP 403 — in that case use the OAuth path documented in `legacy/scrape_reddit_oauth_attempt.R` (requires registering a `script` app at `reddit.com/prefs/apps`).

### 3. Re-merge Trustpilot (optional — data is checked in)

The Trustpilot scrape is done **via the Apify web UI** (one company at a time, max ~1000 reviews each). Download each result CSV into `data/trustpilot_raw/`, then:

```r
source("02_merge_trustpilot.R")
```

Writes `data/trustpilot_reviews.csv`.

### 4. Build the PDFs

In R or RStudio:

```r
rmarkdown::render("coaching_overview.Rmd")
rmarkdown::render("reddit_scrape_comparison.Rmd")
```

PDFs land at the project root (or copy into `outputs/`).

### 5. (Optional) Run the quick analysis script

```r
source("03_preliminary_analysis.R")    # base-R figures into figures/
```

---

## Methodology note: three passes on Reddit

| Pass | Script | Output | Size | Why we moved on |
|---|---|---|---|---|
| v1 — keyword global | `legacy/scraping_data_v1.R` | (discarded) | 14,090 | Single global keyword search → dominated by K-pop, gaming, US politics. <1% mentioned *rental*. Raw CSV no longer kept in repo (re-runnable from the legacy script). |
| v2 — subreddit-targeted | `01_scrape_reddit.R` | `data/reddit_targeted.csv` | 1,009 | Searches inside topic-relevant subs. On-topic but ~67% of corpus was 3 viral threads in r/Filmmakers + r/Entrepreneur about AI-anxiety in creative careers. |
| **v2-cleaned** | **`05_clean_reddit.R`** | **`data/reddit_clean.csv`** | **314** | Drops the 2 noisy subs entirely, tags each comment with a `theme` (`sharing_economy` \| `ai_tech`). 47/53 balanced. **This is the file the analysis uses.** |

The v1-vs-v2 comparison figures: [outputs/reddit_scrape_comparison.pdf](outputs/reddit_scrape_comparison.pdf).

---

## Planned analysis (next steps)

| Step | What | Tools |
|---|---|---|
| 1 | Preprocessing — lemmatise, 1- and 2-grams | `tidytext`, `quanteda` |
| 2 | Word frequency + comparison/commonality clouds | `tidytext`, `wordcloud` |
| 3 | Word co-occurrence networks | `widyr`, `ggraph` |
| 4 | Sentiment (AFINN + NRC 8-emotion) — validated against Trustpilot stars | `syuzhet`, `tidytext` |
| 5 | Topic modelling — 3-5 LDA topics per class, 1g + 2g, seeded | `topicmodels`, `seededlda` |
| 6 | Word embeddings — GloVe via `text2vec`, neighbours of *trust* / *AI* / *host* | `text2vec` |
| 7 | Synthesis — map topics to trust frameworks (Mayer 1995; TAM); produce **AI-agent Design Cards** | — |

---

## Authors

- **Artem Cherkaskyy** & team — WU Vienna, *Online Content Analysis* course, 2026

---

## Limitations

- Trustpilot reviews skew positive (typical of opt-in review platforms) — we downsample for balanced classification.
- Equipment-rental platforms (KitSplit n=5, Lensrentals n=35) are under-sampled (low Trustpilot presence).
- "Trust" appears mostly *implicitly* in the corpora (through host/renter, payment and review language) rather than as the literal word — we measure it via topics and sentiment, not keyword counts.
- English-only.
- **One dominant Reddit thread** ("Ultimate Guide: 86 ChatGPT Plugins") accounts for 26% of `reddit_clean.csv` — AI-side LDA will lean toward "AI tools/plugins" framing. Noted explicitly in the report.
- **Reddit thread count is small** (38 unique threads in `reddit_clean.csv`) — realistic LDA ceiling is 3–4 topics per theme.
- Reddit anti-bot wall (2026) prevents fresh anonymous scrapes; reproducing requires OAuth setup (see `legacy/scrape_reddit_oauth_attempt.R`).

---

## License

Code: [MIT](LICENSE). Scraped data is from public posts; re-users should respect Reddit's and Trustpilot's terms of service.
