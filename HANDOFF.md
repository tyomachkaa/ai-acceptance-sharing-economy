# Project Handoff — Status & Next Steps

**Last updated:** June 8, 2026
**Repo:** https://github.com/tyomachkaa/ai-acceptance-sharing-economy

Short internal status note. Full overview for outsiders: [`README.md`](README.md) and [`outputs/report.pdf`](outputs/report.pdf).

---

## TL;DR for the team

- **Focus:** *AI acceptance across service platforms* — how people accept (or reject) AI agents, and how that changes with AI's **role**: the product itself (ChatGPT, Claude, Replika), a marketplace add-on (Turo, Airbnb), or the support desk (customer-service bots).
- **Data collection: done.** Reddit (discussion baseline) + Trustpilot (star-labelled verification), both on-topic for AI experiences.
- **Analysis: done.** `analysis.R` is the colleague's original steps 1-4 (verbatim, AFINN) plus our steps 5-10 (validation, role gradient, recommendations); his standalone `steps 1 to 4.R` is kept for credit. The report (`report.Rmd` -> `outputs/report.pdf`) is a full methods walkthrough and the presentation base.
- **Headline findings:** (1) the Reddit (AFINN) classes are **validated against real Trustpilot stars: 92.8% agreement, κ = 0.74**; (2) **accuracy and trust** drive negativity in both sources, while **automation leans positive on Reddit (hosts/builders) but is the top negative marker on Trustpilot (end customers)**; (3) AI is penalised as a rental add-on (**2.32★ vs 4.21★**, a 1.89★ gap).

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
| `02_merge_trustpilot.R` | merge Apify Trustpilot CSVs -> `trustpilot_reviews.csv` |
| `06_ai_acceptance.R` | flag AI/automation reviews + categorise platforms |
| `steps 1 to 4.R` | colleague's ORIGINAL steps 1-4 (his credit, untouched) |
| `analysis.R` | **MERGED**: his steps 1-4 verbatim (Part A) + our steps 5-10 (Part B): save his figures, then validation vs stars, AI-role gradient, recommendations -> `figures/fig_*.png` + `outputs/*.csv` |
| `report.Rmd` | final report, reads figures + CSVs live -> `outputs/report.pdf` |

---

## Classes & framing

- **Two classes** for the brief's per-class analysis: **positive vs negative acceptance** — Trustpilot directly from stars (4–5 vs 1–2), Reddit from lexicon sentiment validated against those stars.
- **`platform_category`** (ai_service / rental / customer_service) is the second lens applied to every figure.
- Triangulation: validate the sentiment lexicon on Trustpilot stars → apply to Reddit → compare which topics drive negativity per context.

---

## Status against the brief

**Done (all in `analysis.R`):** 1. Preprocessing. 2. Exploratory (top-words, clouds). 3. Sentiment (NRC). 4. Co-occurrence network. 5. LDA topics. 6. GloVe embeddings. 7. Validation vs Trustpilot stars. 8. AI-role gradient. 9. Strategic recommendations. The report (`report.Rmd`) walks through each method, explains why it was chosen, links references, and ends in the recommendations.

**Remaining (optional / presentation):**
- Build the slide deck from `outputs/report.pdf` + the 11 `figures/fig_*.png` (each maps to a slide).
- (Optional) Extend Trustpilot to AI-native platforms (character.ai, replika.com, openai.com) to populate the Trustpilot `ai_service` cell, then re-run `02` + `06` + `analysis.R`.

**Note on lexicons:** the colleague's code uses the **AFINN** lexicon (via `textdata`) for the positive/negative split and **NRC** (via `syuzhet`) for emotions. AFINN downloads once on first use (accept the RStudio prompt), then runs from cache. AFINN's 92.8% agreement with Trustpilot stars confirms the two-class split is sound.

---

## Setup for a new teammate

```bash
git clone https://github.com/tyomachkaa/ai-acceptance-sharing-economy.git
cd ai-acceptance-sharing-economy
```

```r
install.packages(c(
  "dplyr","tidyr","stringr","readr","scales","rmarkdown","knitr","jsonlite",
  "tidytext","textdata","textstem","tm","wordcloud","RColorBrewer","reshape2",
  "igraph","ggraph","topicmodels","slam","text2vec","syuzhet","ggplot2"
))
```

Everything is R. Run the analysis, then knit:

```r
source("analysis.R")              # figures/fig_*.png + outputs/*.csv  (~30s)
rmarkdown::render("report.Rmd")   # outputs/report.pdf
```

The Reddit collector (`01_...R`) needs only `jsonlite`. `analysis.R` uses the
AFINN lexicon (via textdata): accept the one-time download on first run.

---

## Limitations to flag in the report

- Trustpilot skews positive (opt-in bias) → downsample for classification.
- The Reddit `rental` slice includes a broad `app` keyword pull (some general app noise) — filter via the `source_query` column.
- Trustpilot `ai_service` context not yet populated (AI-native platforms still to scrape).
- "Trust" is mostly *implicit* (bot/human, automated, algorithm language) — measured via topics and sentiment, not keyword counts.
- English-only; Reddit data is archival; Turo/Getaround per-platform review dates need a parse check before per-platform time-series.
