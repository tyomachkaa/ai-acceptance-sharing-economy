# Project Handoff — Status & Next Steps

**Last updated:** May 31, 2026
**Repo:** https://github.com/tyomachkaa/ai-acceptance-sharing-economy

Short internal status note. Full overview for outsiders: [`README.md`](README.md) and [`outputs/report.pdf`](outputs/report.pdf).

---

## TL;DR for the team

- **Focus:** *AI acceptance across service platforms* — how people accept (or reject) AI agents, and how that changes with AI's **role**: the product itself (ChatGPT, Claude, Replika), a marketplace add-on (Turo, Airbnb), or the support desk (customer-service bots).
- **Data collection: done.** Reddit (discussion baseline) + Trustpilot (star-labelled verification), both on-topic for AI experiences.
- **Analysis: not started** — data is ready for preprocessing → frequency → sentiment → LDA.
- **Headline finding so far:** on rental platforms, the 60 reviews mentioning AI/automation average **2.32★ vs 4.21★** overall — automation correlates sharply with frustration.

---

## What we have

### Reddit — discussion baseline (`data/reddit_baseline.csv`, 4,250 comments)

Pulled from the **Arctic Shift** research archive (`01_fetch_reddit_arcticshift.py`), tagged by `platform_category`:

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
| `01_fetch_reddit_arcticshift.py` | Reddit baseline from Arctic Shift (pure Python stdlib) |
| `01b_fetch_reddit_supplement.py` | recovers rate-limited pulls, appends to baseline |
| `02_merge_trustpilot.R` | merge Apify Trustpilot CSVs → `trustpilot_reviews.csv` |
| `06_ai_acceptance.R` | flag AI/automation reviews + categorise platforms |
| `report.Rmd` | working report — reads all CSVs live → `outputs/report.pdf` |

---

## Classes & framing

- **Two classes** for the brief's per-class analysis: **positive vs negative acceptance** — Trustpilot directly from stars (4–5 vs 1–2), Reddit from lexicon sentiment validated against those stars.
- **`platform_category`** (ai_service / rental / customer_service) is the second lens applied to every figure.
- Triangulation: validate the sentiment lexicon on Trustpilot stars → apply to Reddit → compare which topics drive negativity per context.

---

## Next steps (no owners — assign within the team)

1. **Preprocessing** (`07_preprocess.R`) — lowercase, strip punctuation/numbers/stopwords, lemmatise, 1- and 2-gram tokens for both corpora.
2. **Exploratory** — top-10 words per class (bar charts); comparison + commonality word clouds (uni/bi-gram); co-occurrence networks (`widyr` + `ggraph`).
3. **Sentiment** — AFINN + NRC on both corpora, both classes on one graph, validated against Trustpilot stars.
4. **Topic modelling** — 3–5 LDA topics per class, 1g + 2g, seeded; `text2vec` cross-check.
5. **Embeddings** — GloVe/Word2Vec neighbours of *trust* / *AI* / *agent* / *host*.
6. **Synthesis** — map to trust frameworks (Mayer 1995; Davis TAM; UTAUT) → **AI-agent design cards**.

Suggested packages: `tidytext`, `quanteda`, `textstem`, `seededlda`, `topicmodels`, `syuzhet`, `widyr`, `ggraph`, `igraph`, `text2vec`.

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

The Reddit collector is Python 3 (stdlib only — no installs). Re-fetch with
`python3 01_fetch_reddit_arcticshift.py` then `python3 01b_fetch_reddit_supplement.py`.
Build the report with `rmarkdown::render("report.Rmd")`.

---

## Limitations to flag in the report

- Trustpilot skews positive (opt-in bias) → downsample for classification.
- The Reddit `rental` slice includes a broad `app` keyword pull (some general app noise) — filter via the `source_query` column.
- Trustpilot `ai_service` context not yet populated (AI-native platforms still to scrape).
- "Trust" is mostly *implicit* (bot/human, automated, algorithm language) — measured via topics and sentiment, not keyword counts.
- English-only; Reddit data is archival; Turo/Getaround per-platform review dates need a parse check before per-platform time-series.
