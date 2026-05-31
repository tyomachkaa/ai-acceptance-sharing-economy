# =============================================================================
# 01_fetch_reddit_arcticshift.R
# Reddit baseline for the AI-acceptance project, pulled from the Arctic Shift
# research archive (a Pushshift successor) instead of live Reddit.
#
# Why: Reddit's 2026 anti-bot wall hard-blocks every anonymous .json endpoint
# (HTTP 403) -- RedditExtractoR and .json-based scrapers all fail. Arctic Shift
# serves ARCHIVED Reddit over a clean public API. No token, no proxy, no cost.
#
# Pure base R + jsonlite (already installed) -- jsonlite::fromJSON() reads
# directly from the URL, so no httr/curl needed.
#
# API: https://arctic-shift.photon-reddit.com/api/comments/search
#   params: subreddit, body (text search), limit (<=100), sort=desc, before
#
# Output: data/reddit_baseline.csv
# =============================================================================

suppressWarnings(suppressMessages(library(jsonlite)))

options(HTTPUserAgent = "oca-research/1.0 (university text-analysis project)",
        timeout = 60)

BASE   <- "https://arctic-shift.photon-reddit.com/api/comments/search"
FIELDS <- c("id", "subreddit", "author", "score", "created_utc",
            "link_id", "permalink", "body")

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# ---- one API page (with retry/backoff for the archive's rate limit) ---------
fetch_page <- function(subreddit, body = NULL, before = NULL, limit = 100) {
  q <- sprintf("subreddit=%s&limit=%d&sort=desc", subreddit, limit)
  if (!is.null(body))   q <- paste0(q, "&body=", URLencode(body, reserved = TRUE))
  if (!is.null(before)) q <- paste0(q, "&before=", sprintf("%.0f", before))
  url <- paste0(BASE, "?", q)
  delay <- 3
  for (attempt in 1:5) {
    js <- tryCatch(fromJSON(url, simplifyVector = FALSE),
                   error = function(e) NULL)            # HTTP 4xx/timeout -> NULL
    if (!is.null(js)) {
      d <- js$data %||% list()
      if (length(d) == 0) return(data.frame())
      return(do.call(rbind, lapply(d, function(c) data.frame(
        id          = c$id          %||% NA_character_,
        subreddit   = c$subreddit   %||% NA_character_,
        author      = c$author      %||% NA_character_,
        score       = suppressWarnings(as.integer(c$score %||% NA)),
        created_utc = suppressWarnings(as.numeric(c$created_utc %||% NA)),
        link_id     = c$link_id     %||% NA_character_,
        permalink   = c$permalink   %||% NA_character_,
        body        = c$body        %||% NA_character_,
        stringsAsFactors = FALSE))))
    }
    Sys.sleep(delay); delay <- delay * 2                 # back off and retry
  }
  NULL                                                   # gave up
}

# ---- paginate a (subreddit, optional keyword) until target or exhausted -----
pull <- function(subreddit, body = NULL, target = 300, label = "") {
  out <- list(); before <- NULL; got <- 0L; guard <- 0L
  repeat {
    pg <- fetch_page(subreddit, body = body, before = before)
    if (is.null(pg) || nrow(pg) == 0) break
    out[[length(out) + 1]] <- pg
    got <- got + nrow(pg)
    before <- min(pg$created_utc, na.rm = TRUE) - 1      # step back in time
    guard <- guard + 1L
    if (got >= target || nrow(pg) < 100 || guard >= 40) break
    Sys.sleep(0.5)
  }
  res <- if (length(out)) do.call(rbind, out) else NULL
  cat(sprintf("  %-30s %4d comments\n", label, if (is.null(res)) 0 else nrow(res)))
  res
}

# ---- targets ----------------------------------------------------------------
ai_subs <- c("ChatGPT", "OpenAI", "ClaudeAI", "CharacterAI",
             "replika", "artificial", "Bard", "perplexity_ai")

kw_subs <- list(
  list(sub = "Turo",            kws = c("AI", "automated", "bot", "app"),  cat = "rental"),
  list(sub = "AirBnB",          kws = c("AI", "automated", "bot"),         cat = "rental"),
  list(sub = "airbnb_hosts",    kws = c("AI", "automated"),                cat = "rental"),
  list(sub = "CustomerService", kws = c("AI", "automated", "bot"),         cat = "customer_service")
)

cat("=== AI-native subreddits (full pull) ===\n")
ai_dat <- list()
for (s in ai_subs) {
  d <- pull(s, target = 300, label = paste0("r/", s))
  if (!is.null(d)) { d$platform_category <- "ai_service"; d$source_query <- "subreddit"
                     ai_dat[[s]] <- d }
  Sys.sleep(0.5)
}

cat("\n=== Rental / customer-service subs (AI keyword search) ===\n")
kw_dat <- list()
for (t in kw_subs) for (k in t$kws) {
  d <- pull(t$sub, body = k, target = 150, label = sprintf("r/%s body='%s'", t$sub, k))
  if (!is.null(d) && nrow(d)) { d$platform_category <- t$cat; d$source_query <- k
                                kw_dat[[paste(t$sub, k)]] <- d }
  Sys.sleep(0.8)
}

# ---- combine + clean --------------------------------------------------------
all <- do.call(rbind, c(ai_dat, kw_dat))
cat(sprintf("\nRaw pulled: %d comments\n", nrow(all)))

all <- all[!is.na(all$body) &
           !(all$body %in% c("[deleted]", "[removed]", "")) &
           nchar(all$body) >= 20, ]
all <- all[!duplicated(all$id), ]
all$date <- as.Date(as.POSIXct(all$created_utc, origin = "1970-01-01", tz = "UTC"))

dir.create("data", showWarnings = FALSE)
write.csv(all, "data/reddit_baseline.csv", row.names = FALSE)

cat(sprintf("\nFinal: %d unique comments | %d subreddits | %s to %s\n",
            nrow(all), length(unique(all$subreddit)),
            min(all$date, na.rm = TRUE), max(all$date, na.rm = TRUE)))
cat("\nBy platform_category:\n"); print(table(all$platform_category))
cat("\nTop subreddits:\n"); print(head(sort(table(all$subreddit), decreasing = TRUE), 15))
cat("\nWrote data/reddit_baseline.csv\n")
