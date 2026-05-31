# AI Acceptance Across Service Platforms

> A text-analysis project on **how people accept (or reject) AI agents** — and how acceptance changes with the *role* AI plays: the product itself (ChatGPT, Claude, Replika), a marketplace add-on (Turo, Airbnb), or the support desk (customer-service chatbots).

Final project for **Online Content Analysis** at WU Vienna.
We collect two complementary text sources, compare them across three service contexts, and turn the findings into design recommendations for AI agents.

---

## TL;DR

| | What we did | Outcome |
|---|---|---|
| **Sources** | Reddit (discussion baseline) + Trustpilot (verification via star ratings) | 2 self-scraped corpora |
| **Reddit** | Pulled from the Arctic Shift archive across AI / rental / support subreddits | **4,250 on-topic comments**, tagged `ai_service` (2008) / `rental` (1715) / `customer_service` (527) |
| **Trustpilot** | 7 rental platforms via Apify, AI/automation reviews flagged | 3,912 reviews with 1-5★ labels; **60 AI/automation reviews average 2.32★ vs 4.21★** |
| **Headline finding** | On rental platforms, hitting AI/automation correlates sharply with frustration | 2.32★ vs 4.21★ |
| **Collection note** | Reddit's 2026 bot-wall blocks all live scraping (403) → we pull from the Arctic Shift research archive instead | reproducible, no token/proxy |

Read the working report: [outputs/report.pdf](outputs/report.pdf).

---

## Repository layout

```
.
├── README.md                            <- this file
├── LICENSE                              <- MIT
├── .gitignore
│
├── 01_fetch_reddit_arcticshift.py       <- run 1st: Reddit baseline from Arctic Shift archive
├── 01b_fetch_reddit_supplement.py       <- recovers rate-limited pulls, appends to baseline
├── 02_merge_trustpilot.R                <- combine Apify Trustpilot CSVs → trustpilot_reviews.csv
├── 03_preliminary_analysis.R            <- quick exploratory pass + figures
├── 06_ai_acceptance.R                   <- flag AI/automation reviews + tag platform_category
│
├── report.Rmd                           <- working report (auto-reads the CSVs)
├── coaching_overview.Rmd                <- earlier progress report
│
├── data/
│   ├── reddit_baseline.csv              <- USE THIS — 4,250 on-topic comments, 3 categories
│   ├── trustpilot_reviews.csv           <- merged Trustpilot reviews (3,912 rows)
│   ├── trustpilot_flagged.csv           <- + platform_category + ai_related flag
│   ├── ai_experience.csv                <- the 60 AI/automation reviews (2.32★)
│   ├── trustpilot_raw/                  <- per-platform Apify CSVs (inputs)
│   ├── reddit_all.csv                   <- v1 keyword scrape (off-topic, transparency only)
│   ├── reddit_targeted.csv              <- v2 (superseded)
│   └── reddit_clean.csv                 <- v2 cleaned (superseded by reddit_baseline.csv)
│
├── outputs/                             <- knitted PDFs (report.pdf, coaching_overview.pdf, …)
├── figures/                             <- generated PNGs
│
└── legacy/                              <- old / failed attempts kept for transparency
    ├── scraping_data_v1.R               <- original off-topic keyword scrape
    ├── scrape_reddit_oauth_attempt.R    <- OAuth deep-scrape (Reddit form blocked)
    ├── setup_reddit_oauth_test.R
    ├── scrape_trustpilot_api_attempt.R  <- failed Apify API (free-tier capped)
    └── scrape_trustpilot_saswave_attempt.R
```

---

## Research question

> **How do users accept and experience AI agents across different service platforms — and what drives or erodes trust as AI moves from being the product, to a marketplace add-on, to the support desk?**

Online services increasingly put AI between the user and the thing they came for — chatbots answer tickets, algorithms screen and price, automated systems decide. We study how people *react* to that AI across three contexts (**AI-native services**, **peer-to-peer rentals**, **customer service**), and which design factors earn or lose their trust.

---

## Data sources

### Reddit (community discussion — the baseline)

- Tool: the **[Arctic Shift](https://github.com/ArthurHeitmann/arctic_shift) research archive** API (a Pushshift successor). We do **not** scrape live Reddit — its 2026 anti-bot wall hard-blocks every anonymous endpoint (HTTP 403), defeating `RedditExtractoR` and `.json`-based Apify actors alike. Arctic Shift serves archived Reddit over a clean public API: no token, no proxy, no cost.
- Strategy (`01_fetch_reddit_arcticshift.py`): **AI-native subreddits** (r/ChatGPT, r/OpenAI, r/ClaudeAI, r/CharacterAI, r/replika, r/artificial, r/Bard, r/perplexity_ai) pulled in full; **rental + customer-service subreddits** (r/Turo, r/AirBnB, r/airbnb_hosts, r/CustomerService) pulled by AI/automation keyword search. Each comment tagged with a `platform_category`.
- **Output file to use:** `data/reddit_baseline.csv` (4,250 comments — `ai_service` 2008 / `rental` 1715 / `customer_service` 527, 2023–2026).
- `01b_fetch_reddit_supplement.py` recovers any pulls that hit the archive's rate limit, with backoff.

> Earlier sharing-economy-targeted scrapes (`data/reddit_targeted.csv`, `reddit_clean.csv`) are kept for transparency but **superseded** — they were <2% on-topic for AI experiences; the Arctic Shift baseline is ~80%+.

### Trustpilot (paying-customer reviews — the verification)

- Tool: [Apify](https://apify.com) actor `casper11515/trustpilot-reviews-scraper` (run via Apify web UI), one company at a time.
- Platforms scraped: Turo, Fat Llama, RVshare, Outdoorsy, Lensrentals, Getaround, KitSplit → merged by `02_merge_trustpilot.R` → `data/trustpilot_reviews.csv` (3,912 reviews, 1-5★).
- `06_ai_acceptance.R` then tags each review with a `platform_category` and an `ai_related` flag → `data/trustpilot_flagged.csv` + `data/ai_experience.csv` (the 60 AI/automation reviews, **avg 2.32★ vs 4.21★**).
- **To extend** to AI-native services: scrape character.ai / replika.com / openai.com / perplexity.ai into `data/trustpilot_raw/`, re-run `02` then `06` — they auto-tag `ai_service`.

### Why two sources

**Reddit = discussion baseline, Trustpilot = star-labelled verification.**

- Reddit captures *deliberation* — what people say about AI agents in their own words, across the three service contexts.
- Trustpilot captures *post-transaction acceptance* with **1–5★ ground-truth labels** — no lexicon needed.
- We validate the AFINN/NRC sentiment computed on Reddit against Trustpilot stars (convergent validity), then compare which topics drive negativity in each context.

---

## How to reproduce

### 1. Install requirements

```r
install.packages(c(
  "dplyr", "tidyr", "stringr", "purrr",
  "tidytext", "ggplot2", "lubridate", "scales",
  "wordcloud", "RColorBrewer", "rmarkdown", "knitr"
))
```

The Reddit collector is **Python 3 (stdlib only)** — no pip installs needed.

### 2. Re-fetch the Reddit baseline (optional — data is checked in)

```bash
python3 01_fetch_reddit_arcticshift.py    # → data/reddit_baseline.csv (USE THIS)
python3 01b_fetch_reddit_supplement.py    # recovers rate-limited pulls, appends
```

Wall-clock: ~3–4 min. Pulls from the Arctic Shift archive, so no Reddit login / proxy / token.

### 3. Re-merge + flag Trustpilot (optional — data is checked in)

Scrape each company via the Apify web UI, drop the CSVs into `data/trustpilot_raw/`, then:

```r
source("02_merge_trustpilot.R")   # → data/trustpilot_reviews.csv
source("06_ai_acceptance.R")      # → data/trustpilot_flagged.csv + data/ai_experience.csv
```

### 4. Build the report

```r
rmarkdown::render("report.Rmd")   # → report.pdf (copy into outputs/)
```

### 5. (Optional) quick exploratory figures

```r
source("03_preliminary_analysis.R")    # base-R figures into figures/
```

---

## Methodology note: how the Reddit corpus evolved

| Pass | Method | Output | Size | Verdict |
|---|---|---|---|---|
| v1 — keyword global | `legacy/scraping_data_v1.R` | `reddit_all.csv` | 14,090 | Off-topic (K-pop, gaming, politics). Transparency only. |
| v2 — subreddit-targeted | `legacy/…` + `05_clean_reddit.R` | `reddit_clean.csv` | 314 | On-topic for *rentals* but <2% about AI experiences. Superseded. |
| **v3 — Arctic Shift archive** | **`01_fetch_reddit_arcticshift.py`** | **`reddit_baseline.csv`** | **4,250** | **~80%+ on-topic for AI experiences, 3 service contexts. The file the analysis uses.** Live Reddit scraping is blocked in 2026; the archive sidesteps it. |

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

- **Htet Phone Khaing**
- **Tatum Miranda Smith**
- **Artem Cherkaskyy**

WU Vienna — *Online Content Analysis* course, 2026.

---

## Limitations

- Trustpilot reviews skew positive (typical of opt-in review platforms) — we downsample for balanced classification.
- The Reddit `rental` slice was pulled by AI/automation keyword search, including a broad `app` query that adds some general app-experience noise; every row keeps a `source_query` column so it can be filtered precisely.
- The Trustpilot `ai_service` context is not yet populated (AI-native platforms still being scraped); until then the Trustpilot side covers AI-as-add-on only.
- "Trust" appears mostly *implicitly* in the corpora (bot/human, automated, algorithm language) rather than as the literal word — we measure it via topics and sentiment, not keyword counts.
- English-only.
- Reddit data is **archival** (Arctic Shift) because the live anti-bot wall (2026) blocks fresh anonymous scraping. Turo/Getaround per-platform Trustpilot review dates need a parse check before any per-platform time-series.

---

## License

Code: [MIT](LICENSE). Scraped data is from public posts; re-users should respect Reddit's and Trustpilot's terms of service.
