# Project Handoff — Status & Next Steps

**Last updated:** June 8, 2026
**Repo:** https://github.com/tyomachkaa/ai-acceptance-sharing-economy

Short internal status note. Full overview for outsiders: [`README.md`](README.md) and [`outputs/report.pdf`](outputs/report.pdf).

---

## TL;DR for the team

- **Focus:** *AI acceptance across service platforms* — how people accept (or reject) AI agents, and how that changes with AI's **role**: the product itself (ChatGPT, Claude, Replika), a marketplace add-on (Turo, Airbnb), or the support desk (customer-service bots).
- **Data collection: done.** Reddit (discussion baseline) + Trustpilot (star-labelled verification), both on-topic for AI experiences.
- **Analysis: done through step 5.** Steps 1–4 (`steps 1 to 4.R`) cover preprocessing, exploratory, sentiment/network, LDA + GloVe on Reddit; **step 5** (`05_integration.R`) fuses in Trustpilot → `outputs/report.pdf`.
- **Headline findings:** (1) the Reddit sentiment classes are **validated against real Trustpilot stars — 93.4% agreement, κ = 0.76**; (2) four **cross-source frustration drivers** (automation-vs-human, accuracy, support, anthropomorphism); (3) the **AI-role gradient** — AI is accepted when it *is* the product (59% positive on Reddit) but penalised as a rental add-on (**2.32★ vs 4.21★**, a 1.89★ gap).

---

## What we have

### Reddit — discussion baseline (`data/reddit_baseline.csv`, 4,250 comments)

Pulled from the **Arctic Shift** research archive (`01_fetch_reddit_arcticshift.R`), tagged by `platform_category`:

| Category | Comments | Source |
|---|---|---|
| `ai_service` | 2,008 | r/ChatGPT, r/OpenAI, r/ClaudeAI, r/CharacterAI, r/replika, r/artificial, r/Bard, r/perplexity_ai (full pull) |
| `rental` | 1,715 | r/Turo, r/AirBnB, r/airbnb_hosts (AI/automation keyword search) |
| `customer_service` | 527 | r/CustomerService (AI/automation keyword search) |

On-topic check: customer_service ~95%, rental ~85% AI-keyword; ai_service on-topic by subreddit context. Span 2023–2026.

**Why Arctic Shift, not live Reddit:** Reddit's 2026 anti-bot wall hard-blocks every anonymous endpoint (HTTP 403) — `RedditExtractoR` and the `.json`-based Apify actors both fail (we tried both, incl. residential proxy). The archive serves the data over a clean API: no token, no proxy, no cost.

### Trustpilot — verification (`data/trustpilot_reviews.csv`, 3,912 reviews)

7 rental platforms (Turo 1482, Fat Llama 835, RVshare 773, Outdoorsy 751, Lensrentals 35, Getaround 31, KitSplit 5), 1–5★ labels. `06_ai_acceptance.R` then produces:

- `data/trustpilot_flagged.csv` — all reviews + `platform_category` + `ai_related` flag
- `data/ai_experience.csv` — the **60 AI/automation reviews** (avg 2.32★)

**To extend** to AI-native services: scrape character.ai / replika.com / openai.com / perplexity.ai via the Apify web UI into `data/trustpilot_raw/`, then re-run `02_merge_trustpilot.R` + `06_ai_acceptance.R` (they auto-tag `ai_service`).

---

## Pipeline (what's built)

| Script | Purpose |
|---|---|
| `01_fetch_reddit_arcticshift.R` | Reddit baseline from Arctic Shift (base R + jsonlite; retry/backoff built in) |
| `02_merge_trustpilot.R` | merge Apify Trustpilot CSVs → `trustpilot_reviews.csv` |
| `06_ai_acceptance.R` | flag AI/automation reviews + categorise platforms |
| `steps 1 to 4.R` | **Steps 1–4** — Reddit text analysis: preprocess, top-words, clouds, co-occurrence network, NRC, LDA (uni+bigram), GloVe |
| `05_integration.R` | **Step 5** — Reddit×Trustpilot integration: convergent validity, shared themes, AI-role gradient, design cards → `outputs/*.csv` + `figures/05_*.png` |
| `report.Rmd` | working report — reads all CSVs/figures live → `outputs/report.pdf` |

---

## Classes & framing

- **Two classes** for the brief's per-class analysis: **positive vs negative acceptance** — Trustpilot directly from stars (4–5 vs 1–2), Reddit from lexicon sentiment validated against those stars.
- **`platform_category`** (ai_service / rental / customer_service) is the second lens applied to every figure.
- Triangulation: validate the sentiment lexicon on Trustpilot stars → apply to Reddit → compare which topics drive negativity per context.

---

## Status against the brief

**Done:** 1. Preprocessing · 2. Exploratory (top-words, clouds) · 3. Structural & sentiment (network, NRC) · 4. Modelling (LDA, GloVe) — all in `steps 1 to 4.R`. · 5. **Integration / Strategic insights / Literature** — `05_integration.R` + the synthesis sections of `report.Rmd`.

**Remaining (optional / presentation):**
- Build the slide deck from `outputs/report.pdf` + `figures/05_*.png` (the four step-5 figures are presentation-ready).
- (Optional) Extend Trustpilot to AI-native platforms (character.ai, replika.com, openai.com) to populate the Trustpilot `ai_service` cell, then re-run `02` + `06` + `05_integration.R`.

**Note on lexicons:** `steps 1 to 4.R` uses AFINN (`textdata`) + NRC (`syuzhet`); `05_integration.R` deliberately uses the **bundled Bing lexicon** so it runs with no downloads — its 93.4% agreement with stars confirms the two-class split is equivalent.

---

## Setup for a new teammate

```bash
git clone https://github.com/tyomachkaa/ai-acceptance-sharing-economy.git
cd ai-acceptance-sharing-economy
```

```r
install.packages(c(
  "dplyr","tidyr","stringr","purrr","tidytext","ggplot2","lubridate","scales",
  "wordcloud","RColorBrewer","rmarkdown","knitr",
  "quanteda","textstem","seededlda","topicmodels","syuzhet","widyr","ggraph","igraph","text2vec"
))
```

Everything is R now. Re-fetch Reddit with `source("01_fetch_reddit_arcticshift.R")`
(needs only `jsonlite`), and build the report with `rmarkdown::render("report.Rmd")`.

---

## Limitations to flag in the report

- Trustpilot skews positive (opt-in bias) → downsample for classification.
- The Reddit `rental` slice includes a broad `app` keyword pull (some general app noise) — filter via the `source_query` column.
- Trustpilot `ai_service` context not yet populated (AI-native platforms still to scrape).
- "Trust" is mostly *implicit* (bot/human, automated, algorithm language) — measured via topics and sentiment, not keyword counts.
- English-only; Reddit data is archival; Turo/Getaround per-platform review dates need a parse check before per-platform time-series.
