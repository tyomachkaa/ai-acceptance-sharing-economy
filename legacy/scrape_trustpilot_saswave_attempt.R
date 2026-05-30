# =============================================================================
# scrape_trustpilot_saswave.R
# Backup Trustpilot scraper using saswave/unlimited-trustpilot-reviews-scraper.
# This version first FETCHES the actor's input schema to know the exact
# field names before sending the run, so we don't have to guess.
# =============================================================================

suppressPackageStartupMessages({
  for (p in c("httr", "jsonlite", "dplyr", "stringr", "tibble"))
    if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  library(httr); library(jsonlite); library(dplyr); library(stringr); library(tibble)
})

token <- Sys.getenv("APIFY_TOKEN")
if (!nzchar(token)) stop("APIFY_TOKEN not set")

actor <- "saswave~unlimited-trustpilot-reviews-scraper"

platforms <- c("fatllama.com", "kitsplit.com", "sharegrid.com",
               "lensrentals.com", "turo.com", "getaround.com",
               "outdoorsy.com", "rvshare.com")
max_per_platform <- 500

# token check
me <- GET(paste0("https://api.apify.com/v2/users/me?token=", token))
stopifnot(status_code(me) < 300)
cat("Token OK\n")

# ---- step 1: fetch the actor's actual input schema --------------------------
cat("\n--- Fetching input schema ---\n")
ver <- content(GET(paste0("https://api.apify.com/v2/acts/", actor,
                          "/versions/0.0?token=", token)))
schema_raw <- ver$data$inputSchema
if (is.null(schema_raw) || !nchar(schema_raw)) {
  cat("No schema on 0.0 - trying latest version...\n")
  vlist <- content(GET(paste0("https://api.apify.com/v2/acts/", actor,
                              "/versions?token=", token)))$data$items
  for (v in vlist) {
    rr <- content(GET(paste0("https://api.apify.com/v2/acts/", actor,
                             "/versions/", v$versionNumber, "?token=", token)))
    if (!is.null(rr$data$inputSchema) && nchar(rr$data$inputSchema)) {
      schema_raw <- rr$data$inputSchema; break
    }
  }
}

if (is.character(schema_raw) && nchar(schema_raw) > 0) {
  schema <- fromJSON(schema_raw, simplifyVector = FALSE)
  cat("\nINPUT FIELDS (from actor's own schema):\n")
  for (k in names(schema$properties)) {
    p <- schema$properties[[k]]
    cat(sprintf("  %-25s type=%-10s required=%s\n  %s\n  prefill: %s\n",
                k,
                p$type %||% "?",
                isTRUE(k %in% (schema$required %||% list())),
                substr(p$description %||% p$title %||% "", 1, 100),
                if (!is.null(p$prefill)) toJSON(p$prefill, auto_unbox = TRUE) else "(none)"))
  }
} else {
  cat("Could not fetch schema. Falling back to guess.\n")
}

# ---- step 2: build input, trying 'targets' field (from the error trace) ----
# The earlier crash was: `for target in targets:` -> NoneType. So the actor
# expects a top-level `targets` field. Most likely structure: array of objects
# each with a `url` (or `company`) and per-target options.
build_input <- function() {
  list(
    targets = lapply(platforms, function(p) list(
      url      = paste0("https://www.trustpilot.com/review/", p),
      maxItems = max_per_platform
    ))
  )
}
input <- build_input()

cat("\n--- Sending input ---\n")
cat(toJSON(input, auto_unbox = TRUE, pretty = TRUE), "\n")

resp <- POST(
  url    = paste0("https://api.apify.com/v2/acts/", actor,
                  "/runs?token=", token),
  body   = input, encode = "json"
)
if (status_code(resp) >= 300) {
  cat("FAILED to start (HTTP ", status_code(resp), "):\n",
      content(resp, "text"), "\n", sep = "")
  stop("input format rejected at HTTP level - see actor schema above")
}

run        <- content(resp)$data
run_id     <- run$id
dataset_id <- run$defaultDatasetId
cat("Run id=", run_id, "\n", sep = "")

repeat {
  Sys.sleep(15)
  s  <- content(GET(paste0("https://api.apify.com/v2/actor-runs/", run_id,
                           "?token=", token)))$data
  st <- s$status
  n  <- if (!is.null(s$stats$itemCount)) s$stats$itemCount else NA
  cat(format(Sys.time(), "%H:%M:%S"), " status=", st, " items=", n, "\n", sep = "")
  if (st %in% c("SUCCEEDED","FAILED","TIMED-OUT","ABORTED")) break
}

log_txt <- content(GET(paste0("https://api.apify.com/v2/actor-runs/", run_id,
                              "/log?token=", token)), "text", encoding = "UTF-8")
cat("\n--- last 30 log lines ---\n",
    paste(tail(strsplit(log_txt, "\n", fixed = TRUE)[[1]], 30), collapse = "\n"),
    "\n", sep = "")

if (st != "SUCCEEDED") stop("Run did not succeed - see schema + log above")

items <- fromJSON(paste0("https://api.apify.com/v2/datasets/", dataset_id,
                         "/items?format=json&clean=true&token=", token),
                  flatten = TRUE)
cat("\nFetched", nrow(items), "items. Field names:\n"); print(names(items))

if (nrow(items) == 0) stop("Zero items - inspect schema + log above")

pick <- function(df, ...) {
  for (col in c(...))
    if (col %in% names(df) && !all(is.na(df[[col]]))) return(df[[col]])
  rep(NA, nrow(df))
}

biz <- pick(items, "businessUrl", "companyUrl", "url", "companyDomain")
plat <- str_extract(biz, "(?<=trustpilot.com/review/)[^/?]+")
if (all(is.na(plat))) plat <- pick(items, "company", "domain", "companyName")

dat <- tibble(
  platform     = plat,
  review_id    = pick(items, "id", "reviewId"),
  author       = pick(items, "displayName", "reviewerName", "consumerName"),
  title        = pick(items, "title", "reviewTitle"),
  body         = pick(items, "text", "reviewBody", "body"),
  rating       = pick(items, "rating", "stars", "ratingValue"),
  date_posted  = pick(items, "publishedDate", "datePublished", "createdAt"),
  experience   = pick(items, "experiencedDate", "dateOfExperience"),
  n_user_revs  = pick(items, "numberOfReviews"),
  url          = pick(items, "url")
) |>
  filter(!is.na(body), nchar(as.character(body)) >= 20) |>
  distinct(review_id, .keep_all = TRUE)

dir.create("data", showWarnings = FALSE)
out <- "data/trustpilot_reviews.csv"
write.csv(dat, out, row.names = FALSE)
cat("\nSaved", nrow(dat), "reviews ->", out, "\n")
cat("Per-platform:\n"); print(table(dat$platform, useNA = "ifany"))
cat("Per-rating:\n");   print(table(dat$rating, useNA = "ifany"))
cat("Date range:\n");   print(range(as.Date(dat$date_posted), na.rm = TRUE))
