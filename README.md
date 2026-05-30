# AI Acceptance in the Sharing Economy

> A text-analysis project on **how users perceive AI agents on peer-to-peer rental platforms** (Turo, Airbnb, Fat Llama, RVshare, Outdoorsy, KitSplit, …) — and what builds or erodes their trust.

Final project for **Online Content Analysis** at WU Vienna.
We collect two complementary text sources, compare them, and turn the findings into design recommendations for AI agents in rental marketplaces.

---

## TL;DR

| | What we did | Outcome |
|---|---|---|
| **Sources** | Reddit (discussion) + Trustpilot (paying-customer reviews) | 2 self-scraped corpora |
| **Reddit** | Topic-targeted scrape across 30+ subreddits | ~480 on-topic comments (after balancing) |
| **Trustpilot** | 7 sharing-economy platforms via Apify | 3,912 reviews with 1-5★ ground-truth labels |
| **Headline finding** | Trust varies sharply by *rental type* | Car/RV sharing 3.7-4.6★ vs equipment rental 1-3★ |
| **Methodology note** | Initial keyword scrape was off-topic; we caught it, rebuilt with subreddit-scoped search | 6× more relevant corpus |

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
├── 04_compare_versions.R                <- v1-vs-v2 Reddit methodology comparison
│
├── coaching_overview.Rmd                <- main progress report
├── reddit_scrape_comparison.Rmd         <- 3-page methodology note
│
├── data/
│   ├── reddit_all.csv                   <- INITIAL scrape (off-topic baseline)
│   ├── reddit_positive.csv              <- initial "positive class" subset
│   ├── reddit_negative.csv              <- initial "negative class" subset
│   ├── reddit_targeted.csv              <- v2 raw (subreddit-targeted)
│   ├── reddit_targeted_balanced.csv     <- v2 capped per thread (USE THIS)
│   ├── trustpilot_reviews.csv           <- merged Trustpilot reviews
│   └── trustpilot_raw/                  <- per-platform Apify CSVs (inputs)
│
├── outputs/                             <- knitted PDFs
│   ├── coaching_overview.pdf
│   └── reddit_scrape_comparison.pdf
│
├── figures/                             <- generated PNGs
│
└── legacy/                              <- old / failed attempts kept for transparency
    ├── scraping_data_v1.R               <- the original off-topic keyword scrape
    ├── scrape_trustpilot_api_attempt.R  <- failed Apify API (free-tier capped)
    └── scrape_trustpilot_saswave_attempt.R
```

---

## Research question

> **How do users perceive AI agents on peer-to-peer rental platforms, and what drives trust — across platform types and across community discussion (Reddit) vs. paying-customer experience (Trustpilot)?**

The sharing economy increasingly embeds AI for matching, messaging, pricing and damage assessment. We study how users *react* to that automation and which design factors earn (or lose) their trust.

---

## Data sources

### Reddit (community discussion)

- Tool: [`RedditExtractoR`](https://cran.r-project.org/package=RedditExtractoR) (R, public Reddit API)
- Strategy: **subreddit-scoped keyword search** across 30+ communities (r/Turo, r/AirBnB, r/photography, r/drones, r/Filmmakers, r/Entrepreneur, r/privacy, …)
- Output: `data/reddit_targeted_balanced.csv` — the main file used downstream
- See `01_scrape_reddit.R`

### Trustpilot (paying-customer reviews)

- Tool: [Apify](https://apify.com) actor `casper11515/trustpilot-reviews-scraper` (run via Apify web UI)
- Platforms scraped: Turo, Fat Llama, RVshare, Outdoorsy, Lensrentals, Getaround, KitSplit
- Each result CSV downloaded into `data/trustpilot_raw/`, then merged with `02_merge_trustpilot.R`
- Output: `data/trustpilot_reviews.csv` — 3,912 reviews, 1-5★ ratings = real sentiment ground truth

### Why two sources

Reddit captures *deliberation* — host/renter disputes, complaints, debates.
Trustpilot captures *post-transaction satisfaction* — service quality, ease of use.
Together they triangulate the same research question from two angles. The two sources also let us *validate* lexicon sentiment on Reddit against Trustpilot stars (convergent validity).

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
source("01_scrape_reddit.R")
```

Wall-clock: ~30-45 min (Reddit comment fetch is rate-limited).
Writes: `data/reddit_targeted.csv` (raw) + `data/reddit_targeted_balanced.csv` (capped).

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
source("04_compare_versions.R")        # v1 vs v2 Reddit comparison
```

---

## Methodology note: why we re-scraped Reddit

The initial collection (`legacy/scraping_data_v1.R`) used a single global keyword search across all of Reddit. Result: a 14,090-comment corpus dominated by K-pop drama, gaming, and U.S. politics — less than 1% of comments mentioned *rental*.

The revised scrape (`01_scrape_reddit.R`) searches **inside topic-relevant subreddits** with focused keywords, and caps comments per thread so no single viral thread dominates. Result: a smaller (~480) but ~6× more relevant corpus.

Full comparison with figures: [outputs/reddit_scrape_comparison.pdf](outputs/reddit_scrape_comparison.pdf).

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
- Equipment-rental platforms (KitSplit, Lensrentals) are under-sampled (low Trustpilot presence).
- "Trust" appears mostly *implicitly* in the corpora (through host/renter, payment and review language) rather than as the literal word — we measure it via topics and sentiment, not keyword counts.
- English-only.
- Reddit comments are kept as-is from on-topic threads — some off-topic chatter within those threads is expected.

---

## License

Code: [MIT](LICENSE). Scraped data is from public posts; re-users should respect Reddit's and Trustpilot's terms of service.
