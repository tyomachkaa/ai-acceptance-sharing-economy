# =============================================================================
# scrape_reddit_v2.R
# Targeted Reddit scrape for AI Acceptance in the Sharing Economy.
#
# Why this exists:
#   The original `scraping data.R` searched all of Reddit with generic keyword
#   queries ("AI rental platform helpful automation trust"), which returned
#   threads about K-pop drama, Genshin Impact, AITA stories, Stalker 2 reviews,
#   and US politics - <1% of comments mention "rental", 0.1% mention "drone".
#   That corpus is essentially off-topic.
#
# What this fixes:
#   1) Search INSIDE topic-relevant subreddits (sharing economy, photography,
#      drones, filmmaking, event tech, AI tools) - not all of Reddit.
#   2) Filter with AI-related keywords so we only keep threads where AI
#      actually comes up.
#   3) Do NOT bias the class label with keyword choice. The label is derived
#      downstream from sentiment lexicon (AFINN/NRC) on the actual comment
#      text - same as Trustpilot's star rating gives a ground-truth label.
#   4) Keep subreddit + thread metadata for cross-community analysis.
#
# Output: data/reddit_targeted.csv
# =============================================================================

suppressPackageStartupMessages({
  for (p in c("RedditExtractoR", "dplyr", "stringr", "purrr"))
    if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  library(RedditExtractoR); library(dplyr); library(stringr); library(purrr)
})

# ---- targets ---------------------------------------------------------------
# Each row: (subreddit, search keyword) — RedditExtractoR's find_thread_urls
# supports searching INSIDE a single subreddit, which is what makes the
# results topic-relevant.

targets <- tibble::tribble(
  ~subreddit,            ~keyword,
  # --- home / stay sharing (AirBnB + alternatives) ---
  "AirBnB",              "AI",
  "AirBnB",              "host AI",
  "AirBnB",              "automated message",
  "AirBnB",              "co-host",
  "AirBnB",              "automated",
  "airbnb_hosts",        "AI",
  "airbnb_hosts",        "automation",
  "AirBnBHosts",         "AI",
  "vrbo",                "AI",
  "vrbo",                "automated",
  "ShortTermRentals",    "AI",
  # --- car / RV sharing ---
  "Turo",                "AI",
  "Turo",                "automated",
  "Turo",                "trust",
  "Turo",                "host",
  "Turo",                "app",
  "gigwork",             "AI",
  "RVing",               "rental AI",
  "GoRVing",             "rental",
  # --- camera / film / drone gear ---
  "photography",         "AI rental",
  "photography",         "lens rental",
  "photography",         "rent gear",
  "AskPhotography",      "rental",
  "cinematography",      "AI",
  "videography",         "AI",
  "Filmmakers",          "AI",
  "drones",              "AI",
  "drones",              "rental",
  "dronephotography",    "AI",
  "DJI",                 "AI",
  # --- event tech ---
  "eventproduction",     "AI",
  "EventProduction",     "AI",
  "livesound",           "AI",
  # --- AI agents in commerce / marketplaces ---
  "Entrepreneur",        "AI agent",
  "Entrepreneur",        "automation rental",
  "SaaS",                "AI agent",
  "startups",            "AI agent",
  "automation",          "rental",
  "automation",          "property",
  "ChatGPT",             "rental",
  "OpenAI",              "agent booking",
  "artificial",          "agent trust",
  "singularity",         "rental agent",
  # --- trust / privacy concerns about AI ---
  "privacy",             "AI agent",
  "privacy",             "AI assistant data",
  "technology",          "AI agent trust"
)

threads_per_search <- 30  # more thread candidates per query
period             <- "all" # full history - older threads have accumulated comments
cap_per_thread     <- 120  # max comments kept per thread (was 50) -> bigger corpus

cat("Will run ", nrow(targets), " (subreddit, keyword) searches, ",
    threads_per_search, " threads each.\n", sep = "")

# ---- step 1: find thread URLs ----------------------------------------------
# RedditExtractoR::find_thread_urls supports filtering by subreddit, which is
# what makes the results topic-relevant.

find_safe <- function(subreddit, keyword) {
  tryCatch({
    r <- find_thread_urls(
      keywords  = keyword,
      sort_by   = "relevance",
      period    = period,
      subreddit = subreddit
    )
    if (is.null(r) || !nrow(r)) return(NULL)
    head(r, threads_per_search) |>
      mutate(search_keyword = keyword, search_subreddit = subreddit)
  }, error = function(e) {
    cat("  WARN ", subreddit, "/", keyword, ": ", conditionMessage(e), "\n",
        sep = "")
    NULL
  })
}

cat("\n--- Finding threads ---\n")
all_threads <- pmap(targets, function(subreddit, keyword) {
  cat("  r/", subreddit, " <- '", keyword, "'\n", sep = "")
  find_safe(subreddit, keyword)
}) |> bind_rows() |> distinct(url, .keep_all = TRUE)

cat("\nFound", nrow(all_threads), "unique threads across",
    length(unique(all_threads$subreddit)), "subreddits.\n")

# Only keep threads with real discussion (>=6 comments). Low-engagement
# threads are 1-2 OP-only replies and waste a fetch each.
all_threads <- all_threads |>
  filter(!is.na(url), comments >= 6) |>
  arrange(desc(comments))  # fetch the highest-engagement threads first
cat("After requiring >=6 comments:", nrow(all_threads), "threads.\n")

# ---- step 2: fetch comments -------------------------------------------------
# get_thread_content is rate-limited; cap total threads to keep wall-clock
# reasonable. ~400 threads * ~25 comments avg -> several thousand comments.

max_threads <- 400
if (nrow(all_threads) > max_threads) {
  set.seed(2026)
  all_threads <- all_threads |> slice_sample(n = max_threads)
  cat("Capped to", max_threads, "threads.\n")
}

cat("\n--- Fetching comments (", nrow(all_threads), " threads) ---\n", sep = "")
all_comments <- list()
# checkpoint every 25 threads so a late crash doesn't lose the run
dir.create("data", showWarnings = FALSE)
ckpt_path <- "data/_reddit_v2_checkpoint.rds"
for (i in seq_len(nrow(all_threads))) {
  u <- all_threads$url[i]
  cat(sprintf("  %3d/%d %s\n", i, nrow(all_threads), substr(u, 1, 90)))
  out <- tryCatch(get_thread_content(u), error = function(e) NULL)
  if (is.null(out) || is.null(out$comments) || !nrow(out$comments)) next

  cmt <- out$comments
  # Force every column to character so bind_rows() can't crash on type drift
  cmt[] <- lapply(cmt, as.character)
  # NULL-safe single-value extractor: returns NA_character_ if the source
  # field is empty / NULL / length-0 (some old threads have missing score).
  safe1 <- function(x) {
    if (is.null(x) || length(x) == 0) return(NA_character_)
    as.character(x[[1]])
  }
  cmt$subreddit         <- safe1(all_threads$subreddit[i])
  cmt$search_keyword    <- safe1(all_threads$search_keyword[i])
  cmt$thread_title      <- safe1(all_threads$title[i])
  cmt$thread_score      <- safe1(all_threads$score[i])
  all_comments[[length(all_comments) + 1]] <- cmt
  if (i %% 25 == 0) saveRDS(all_comments, ckpt_path)  # checkpoint
  Sys.sleep(1)  # be polite
}
saveRDS(all_comments, ckpt_path)  # final checkpoint

# ---- step 3: tidy + save ---------------------------------------------------
if (length(all_comments) == 0) stop("No comments fetched - check Reddit access")

dat <- bind_rows(all_comments) |>
  filter(!is.na(comment), nchar(comment) >= 20,
         !comment %in% c("[deleted]", "[removed]")) |>
  distinct(comment_id, .keep_all = TRUE)

dir.create("data", showWarnings = FALSE)

# RAW = every comment from every matched thread
write.csv(dat, "data/reddit_targeted.csv", row.names = FALSE)

# BALANCED = cap each thread to cap_per_thread (keep highest-upvoted) so a
# single viral thread can't dominate. Bigger cap -> bigger corpus.
dat$upv <- suppressWarnings(as.numeric(dat$upvotes)); dat$upv[is.na(dat$upv)] <- 0
ord <- dat[order(dat$url, -dat$upv), ]
bal <- do.call(rbind, lapply(split(ord, ord$url),
                             function(x) head(x, cap_per_thread)))
rownames(bal) <- NULL
shar <- c("Turo","turo","AirBnB","airbnb_hosts","AirBnBHosts","vrbo",
          "ShortTermRentals","RVing","GoRVing","EventProduction","eventproduction")
bal$theme <- ifelse(bal$subreddit %in% shar, "sharing_economy", "ai_creative_tech")
write.csv(bal, "data/reddit_targeted_balanced.csv", row.names = FALSE)

cat("\nSaved RAW      ", nrow(dat), " comments -> data/reddit_targeted.csv\n", sep = "")
cat("Saved BALANCED ", nrow(bal), " comments (cap ", cap_per_thread,
    "/thread) -> data/reddit_targeted_balanced.csv\n", sep = "")

# diagnostics on the balanced set
cat("\nPer-subreddit counts (balanced, top 15):\n")
print(head(sort(table(bal$subreddit), decreasing = TRUE), 15))
cat("\nTheme split (balanced):\n"); print(table(bal$theme))
cat("\nDate range:", as.character(range(as.Date(bal$date), na.rm = TRUE)), "\n")
cat("Mean comment length:", round(mean(nchar(bal$comment))), "chars\n")

cat("\nKeyword coverage (balanced):\n")
for (kw in c("AI","agent","automation","trust","privacy","rental","rent",
             "host","airbnb","turo","drone","camera")) {
  hits <- sum(grepl(kw, bal$comment, ignore.case = TRUE))
  cat(sprintf("  %-12s %5d  (%4.1f%%)\n", kw, hits, 100 * hits / nrow(bal)))
}
