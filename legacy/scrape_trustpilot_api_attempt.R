# =============================================================================
# scrape_trustpilot.R
# Trustpilot reviews for sharing-economy / peer-to-peer rental platforms via
# Apify's automation-lab/trustpilot actor (26k+ runs, actively maintained,
# documented input schema).
#
# Input format (from the actor's own docs):
#   { "companyUrls": ["pipedrive.com", ...], "maxReviewsPerCompany": 100,
#     "sort": "recency", "includeCompanyInfo": true }
#
# Output fields include: text, rating, title, publishedDate, experienceDate,
#   authorName, country, companyDomain, companyName, companyTotalReviews.
#
# Setup:
#   Sys.setenv(APIFY_TOKEN = "apify_api_xxxx"); source("scrape_trustpilot.R")
# =============================================================================

suppressPackageStartupMessages({
  for (p in c("httr", "jsonlite", "dplyr", "stringr", "tibble"))
    if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  library(httr); library(jsonlite); library(dplyr); library(stringr); library(tibble)
})

token <- Sys.getenv("APIFY_TOKEN")
if (!nzchar(token)) stop("APIFY_TOKEN not set")

actor <- "automation-lab~trustpilot"

# bare domains - the actor resolves these to Trustpilot pages itself
company_domains <- c(
  "fatllama.com", "kitsplit.com", "sharegrid.com", "lensrentals.com",
  "turo.com", "getaround.com", "outdoorsy.com", "rvshare.com"
)
max_per_company <- 500          # set to 0 for ALL reviews per company

# token check
me <- GET(paste0("https://api.apify.com/v2/users/me?token=", token))
stopifnot(status_code(me) < 300)
cat("Token OK - user:", content(me)$data$username, "\n")

# ---- run --------------------------------------------------------------------
input <- list(
  companyUrls          = as.list(company_domains),
  maxReviewsPerCompany = max_per_company,
  sort                 = "recency",
  includeCompanyInfo   = TRUE
)
cat("Sending input:\n"); cat(toJSON(input, auto_unbox = TRUE, pretty = TRUE), "\n")

resp <- POST(paste0("https://api.apify.com/v2/acts/", actor,
                    "/runs?token=", token),
             body = input, encode = "json")
if (status_code(resp) >= 300)
  stop("Failed to start (HTTP ", status_code(resp), "): ", content(resp, "text"))

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

# always show log tail (diagnostic)
log_txt <- content(GET(paste0("https://api.apify.com/v2/actor-runs/", run_id,
                              "/log?token=", token)), "text", encoding = "UTF-8")
cat("\n--- last 25 log lines ---\n",
    paste(tail(strsplit(log_txt, "\n", fixed = TRUE)[[1]], 25), collapse = "\n"), "\n", sep = "")

if (st != "SUCCEEDED") stop("Run did not succeed - see log above")

items <- fromJSON(paste0("https://api.apify.com/v2/datasets/", dataset_id,
                         "/items?format=json&clean=true&token=", token),
                  flatten = TRUE)
cat("\nFetched", nrow(items), "items\n")
if (nrow(items) == 0) stop("Zero items - see log above")

pick <- function(df, ...) {
  for (col in c(...))
    if (col %in% names(df) && !all(is.na(df[[col]]))) return(df[[col]])
  rep(NA, nrow(df))
}

dat <- tibble(
  platform        = pick(items, "companyDomain", "companyName"),
  review_id       = pick(items, "reviewId", "id"),
  author          = pick(items, "authorName"),
  country         = pick(items, "country"),
  title           = pick(items, "title"),
  body            = pick(items, "text"),
  rating          = pick(items, "rating"),
  date_posted     = pick(items, "publishedDate"),
  experience      = pick(items, "experienceDate"),
  verified        = pick(items, "isVerified"),
  company_total   = pick(items, "companyTotalReviews"),
  company_score   = pick(items, "companyTrustScore"),
  url             = pick(items, "reviewUrl")
) |>
  filter(!is.na(body), nchar(as.character(body)) >= 20) |>
  distinct(review_id, .keep_all = TRUE)

dir.create("data", showWarnings = FALSE)
out <- "data/trustpilot_reviews.csv"
write.csv(dat, out, row.names = FALSE)

cat("\nSaved", nrow(dat), "reviews ->", out, "\n")
cat("\nPer-platform:\n");  print(table(dat$platform, useNA = "ifany"))
cat("\nPer-rating:\n");    print(table(dat$rating, useNA = "ifany"))
cat("\nDate range:\n");    print(range(as.Date(dat$date_posted), na.rm = TRUE))
