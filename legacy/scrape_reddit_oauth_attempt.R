# 01b_scrape_reddit_deep.R
# -------------------------------------------------------------------
# DEEP / EXTENSIVE Reddit scrape via OAUTH (anonymous endpoints are
# now blocked by Reddit's bot wall, so we go through oauth.reddit.com).
#
# Requires .Renviron entries:
#   REDDIT_CLIENT_ID=...
#   REDDIT_CLIENT_SECRET=...
#   REDDIT_USER_AGENT=oca-deep-scraper/0.1 by /u/YOUR_USERNAME
#
# Wide scope:
#   - 38 subreddits across 5 layers
#   - ~340 (subreddit, keyword) search pairs
#   - Two sort orders per pair: "relevance" + "top"
#   - Up to 100 threads per search call
#   - period = "all"
#   - min 4 comments per thread
#   - max 2000 unique threads (cap)
#   - NO per-thread comment cap
#   - Checkpoints every 25 threads (resumable)
#
# Output: data/reddit_deep.csv
# -------------------------------------------------------------------

suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
  library(dplyr)
  library(stringr)
  library(purrr)
})

set.seed(42)

# -------------------------------------------------------------------
# 0.  OAUTH HELPER
# -------------------------------------------------------------------

UA <- Sys.getenv("REDDIT_USER_AGENT")
CID <- Sys.getenv("REDDIT_CLIENT_ID")
CSEC <- Sys.getenv("REDDIT_CLIENT_SECRET")

stopifnot(nzchar(UA), nzchar(CID), nzchar(CSEC))

get_token <- function() {
  resp <- httr::POST(
    "https://www.reddit.com/api/v1/access_token",
    httr::authenticate(CID, CSEC),
    body = list(grant_type = "client_credentials"),
    encode = "form",
    httr::user_agent(UA)
  )
  if (httr::status_code(resp) != 200) {
    stop("Reddit OAuth failed: HTTP ", httr::status_code(resp),
         " body: ", substr(httr::content(resp, "text"), 1, 200))
  }
  tok <- httr::content(resp)$access_token
  if (is.null(tok)) stop("Reddit returned no token.")
  tok
}

TOKEN <- get_token()
TOKEN_TIME <- as.numeric(Sys.time())

# refresh token if older than 50 min
refresh_if_stale <- function() {
  if (as.numeric(Sys.time()) - TOKEN_TIME > 50 * 60) {
    TOKEN     <<- get_token()
    TOKEN_TIME <<- as.numeric(Sys.time())
  }
}

api_get <- function(path_with_query) {
  refresh_if_stale()
  url <- paste0("https://oauth.reddit.com", path_with_query)
  resp <- httr::GET(
    url,
    httr::add_headers(Authorization = paste("Bearer", TOKEN)),
    httr::user_agent(UA),
    httr::timeout(30)
  )
  # token expired? re-auth once and retry
  if (httr::status_code(resp) == 401) {
    TOKEN <<- get_token()
    TOKEN_TIME <<- as.numeric(Sys.time())
    resp <- httr::GET(
      url,
      httr::add_headers(Authorization = paste("Bearer", TOKEN)),
      httr::user_agent(UA),
      httr::timeout(30)
    )
  }
  # mild rate-limit awareness
  rem <- as.numeric(httr::headers(resp)[["x-ratelimit-remaining"]])
  if (!is.na(rem) && rem < 5) {
    reset <- as.numeric(httr::headers(resp)[["x-ratelimit-reset"]])
    if (!is.na(reset) && reset > 0) {
      Sys.sleep(min(reset + 1, 60))
    }
  }
  if (httr::status_code(resp) >= 400) {
    stop("HTTP ", httr::status_code(resp), " on ", path_with_query)
  }
  jsonlite::fromJSON(
    httr::content(resp, as = "text", encoding = "UTF-8"),
    simplifyVector = FALSE
  )
}

# -------------------------------------------------------------------
# 1.  SUBREDDIT x KEYWORD MATRIX (same as the RedditExtractoR draft)
# -------------------------------------------------------------------

share_subs <- c(
  "AirBnB", "airbnb_hosts", "AirBnBHosts", "vrbo", "ShortTermRentals",
  "Hosting", "Turo", "RVing", "GoRVing", "gigwork", "couchsurfing"
)
gear_subs <- c(
  "photography", "AskPhotography", "cinematography", "videography",
  "drones", "dronephotography", "DJI",
  "eventproduction", "EventProduction", "livesound"
)
ai_subs <- c(
  "ChatGPT", "OpenAI", "ArtificialInteligence", "artificial",
  "AI_Agents", "singularity", "agi", "ClaudeAI",
  "automation", "MachineLearning"
)
biz_subs <- c("Entrepreneur", "SaaS", "startups", "smallbusiness")
trust_subs <- c("privacy", "cybersecurity", "Scams")

ai_in_share_kw <- c(
  "AI", "ChatGPT", "AI agent", "chatbot",
  "automated", "smart pricing", "AI host",
  "AI screening", "AI customer service", "AI tool"
)
rental_in_ai_kw <- c(
  "AirBnB", "Turo", "rental", "host",
  "Fat Llama", "RVshare", "camera rental",
  "drone rental", "sharing economy", "peer-to-peer"
)
biz_ai_kw   <- c("AI agent", "AI tool", "automation", "ChatGPT", "AI rental")
trust_ai_kw <- c("AI scam", "AI fake review", "AI fraud", "AI host")

targets <- bind_rows(
  expand.grid(subreddit = share_subs, keyword = ai_in_share_kw,
              stringsAsFactors = FALSE),
  expand.grid(subreddit = gear_subs,  keyword = ai_in_share_kw,
              stringsAsFactors = FALSE),
  expand.grid(subreddit = ai_subs,    keyword = rental_in_ai_kw,
              stringsAsFactors = FALSE),
  expand.grid(subreddit = biz_subs,   keyword = biz_ai_kw,
              stringsAsFactors = FALSE),
  expand.grid(subreddit = trust_subs, keyword = trust_ai_kw,
              stringsAsFactors = FALSE)
) |> distinct()

sort_orders <- c("relevance", "top")
threads_per_search <- 40

cat(sprintf("Search matrix: %d pairs x %d sorts = %d API calls.\n",
            nrow(targets), length(sort_orders),
            nrow(targets) * length(sort_orders)))

# -------------------------------------------------------------------
# 2.  PARAMETERS + paths
# -------------------------------------------------------------------
period             <- "all"
min_comments       <- 4
max_unique_threads <- 2000

out_csv     <- "data/reddit_deep.csv"
ck_threads  <- "data/_deep_thread_meta.rds"
ck_comments <- "data/_deep_comments.rds"

dir.create("data", showWarnings = FALSE)
dir.create("logs", showWarnings = FALSE)

# -------------------------------------------------------------------
# 3.  PHASE 1 - search
# -------------------------------------------------------------------
cat("\n=== Phase 1: searching ===\n")

extract_threads <- function(listing_json) {
  kids <- listing_json$data$children
  if (length(kids) == 0) return(NULL)
  dplyr::bind_rows(lapply(kids, function(k) {
    d <- k$data
    data.frame(
      thread_id    = d$id      %||% NA_character_,
      title        = d$title   %||% NA_character_,
      subreddit    = d$subreddit %||% NA_character_,
      url          = paste0("https://www.reddit.com", d$permalink %||% ""),
      n_comments   = d$num_comments %||% NA_integer_,
      score        = d$score %||% NA_integer_,
      created_utc  = d$created_utc %||% NA_real_,
      stringsAsFactors = FALSE
    )
  }))
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

if (file.exists(ck_threads)) {
  thread_meta <- readRDS(ck_threads)
  cat(sprintf("Loaded checkpointed thread meta: %d unique threads.\n",
              nrow(thread_meta)))
} else {
  bucket <- list()
  for (i in seq_len(nrow(targets))) {
    sub <- targets$subreddit[i]
    kw  <- targets$keyword[i]
    for (sort_by in sort_orders) {
      path <- sprintf(
        "/r/%s/search?q=%s&restrict_sr=on&sort=%s&t=%s&limit=100",
        sub, URLencode(kw, reserved = TRUE), sort_by, period
      )
      tryCatch({
        js <- api_get(path)
        df <- extract_threads(js)
        if (!is.null(df) && nrow(df) > 0) {
          df <- head(df, threads_per_search)
          df$keyword_searched <- kw
          df$sort_used        <- sort_by
          bucket[[length(bucket) + 1]] <- df
        }
      }, error = function(e) {
        message(sprintf("  ! %s/%s [%s] -- %s",
                        sub, kw, sort_by, conditionMessage(e)))
      })
      Sys.sleep(1.1)  # ~55 req/min, under Reddit's 60/min cap
    }
    if (i %% 20 == 0) {
      cat(sprintf("  search progress: %d / %d pairs\n",
                  i, nrow(targets)))
    }
  }

  thread_meta <- bind_rows(bucket) |>
    distinct(thread_id, .keep_all = TRUE) |>
    filter(!is.na(n_comments), n_comments >= min_comments)

  cat(sprintf("\nUnique threads (>= %d comments): %d\n",
              min_comments, nrow(thread_meta)))

  if (nrow(thread_meta) > max_unique_threads) {
    thread_meta <- thread_meta |>
      arrange(desc(n_comments)) |>
      slice_head(n = max_unique_threads)
    cat(sprintf("Capped at %d threads.\n", max_unique_threads))
  }

  saveRDS(thread_meta, ck_threads)
}

# -------------------------------------------------------------------
# 4.  PHASE 2 - thread contents
# -------------------------------------------------------------------
cat("\n=== Phase 2: pulling threads ===\n")

walk_comments <- function(node, depth = 0L) {
  if (is.null(node$kind) || node$kind != "t1") return(NULL)
  d <- node$data
  row <- data.frame(
    comment_id  = d$id        %||% NA_character_,
    author      = d$author    %||% NA_character_,
    score       = d$score     %||% NA_integer_,
    created_utc = d$created_utc %||% NA_real_,
    depth       = depth,
    comment     = d$body      %||% NA_character_,
    stringsAsFactors = FALSE
  )
  children <- tryCatch(d$replies$data$children, error = function(e) NULL)
  if (!is.null(children) && length(children) > 0) {
    sub_rows <- lapply(children, walk_comments, depth = depth + 1L)
    sub_rows <- Filter(Negate(is.null), sub_rows)
    if (length(sub_rows) > 0) {
      row <- bind_rows(c(list(row), sub_rows))
    }
  }
  row
}

fetch_thread <- function(sub, thread_id) {
  path <- sprintf(
    "/r/%s/comments/%s?limit=500&depth=20&sort=top",
    sub, thread_id
  )
  js <- api_get(path)
  post <- js[[1]]$data$children[[1]]$data
  cmt_root <- js[[2]]$data$children
  rows <- lapply(cmt_root, walk_comments)
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0) return(NULL)
  cmt <- bind_rows(rows)
  cmt$thread_id    <- thread_id
  cmt$thread_title <- post$title %||% NA_character_
  cmt$subreddit    <- post$subreddit %||% sub
  cmt$thread_score <- post$score %||% NA_integer_
  cmt$thread_ts    <- post$created_utc %||% NA_real_
  cmt
}

prior <- NULL
done_ids <- character()
if (file.exists(ck_comments)) {
  prior <- readRDS(ck_comments)
  done_ids <- unique(prior$thread_id)
  cat(sprintf("Resuming: %d threads already fetched.\n", length(done_ids)))
}

todo <- setdiff(thread_meta$thread_id, done_ids)
cat(sprintf("Threads to fetch this run: %d\n", length(todo)))

bucket <- if (!is.null(prior)) list(prior) else list()

for (j in seq_along(todo)) {
  tid <- todo[j]
  sub <- thread_meta$subreddit[match(tid, thread_meta$thread_id)]
  tryCatch({
    one <- fetch_thread(sub, tid)
    if (!is.null(one) && nrow(one) > 0) {
      bucket[[length(bucket) + 1]] <- one
    }
  }, error = function(e) {
    message(sprintf("  ! %s/%s -- %s", sub, tid, conditionMessage(e)))
  })
  if (j %% 25 == 0) {
    saveRDS(bind_rows(bucket), ck_comments)
    cat(sprintf("  fetched %d / %d threads (checkpointed).\n",
                j, length(todo)))
  }
  Sys.sleep(1.1)
}

saveRDS(bind_rows(bucket), ck_comments)

# -------------------------------------------------------------------
# 5.  PHASE 3 - clean + write CSV
# -------------------------------------------------------------------
cat("\n=== Phase 3: cleaning ===\n")

all_cmt <- bind_rows(bucket) |>
  filter(
    !is.na(comment),
    !comment %in% c("[deleted]", "[removed]", ""),
    nchar(comment) >= 20
  ) |>
  distinct(comment_id, .keep_all = TRUE)

share_layer <- c(share_subs, gear_subs)
all_cmt <- all_cmt |>
  mutate(theme = ifelse(subreddit %in% share_layer,
                        "sharing_economy", "ai_creative_tech"))

cat(sprintf("Final corpus: %d comments | %d threads | %d subreddits\n",
            nrow(all_cmt),
            length(unique(all_cmt$thread_id)),
            length(unique(all_cmt$subreddit))))

cat("\nTop 15 subreddits:\n")
print(all_cmt |> count(subreddit, sort = TRUE) |> slice_head(n = 15))

cat("\nTop 10 threads:\n")
print(all_cmt |> count(thread_title, subreddit, sort = TRUE) |> slice_head(n = 10))

write.csv(all_cmt, out_csv, row.names = FALSE)
cat(sprintf("\nWrote %s\n", out_csv))
cat("Done.\n")
