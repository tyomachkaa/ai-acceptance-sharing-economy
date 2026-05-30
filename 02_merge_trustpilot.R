# =============================================================================
# merge_trustpilot.R
# Combines all Trustpilot CSVs downloaded from the Apify web UI
# (casper11515/trustpilot-reviews-scraper) into one clean dataset.
# Base-R only - no package dependencies.
#
# Usage:
#   1. In the Apify web UI, run the Trustpilot actor once per company
#      (fatllama.com, kitsplit.com, turo.com, getaround.com, outdoorsy.com,
#      rvshare.com, lensrentals.com, sharegrid.com), max reviews ~1000-2000.
#   2. Download each result CSV and drop them ALL into:
#        Final Project/data/trustpilot_raw/
#      (any filenames are fine - the script reads every .csv in that folder)
#   3. source("merge_trustpilot.R")
#
# Output: data/trustpilot_reviews.csv
# =============================================================================

raw_dir <- "data/trustpilot_raw"
files   <- list.files(raw_dir, pattern = "\\.csv$", full.names = TRUE)
if (length(files) == 0)
  stop("No CSVs in ", raw_dir, " - download from the Apify UI first.")
cat("Found", length(files), "CSV file(s):\n  ",
    paste(basename(files), collapse = "\n  "), "\n")

# robust reader: strip BOM, carriage returns, invalid UTF-8 bytes, then read
read_clean <- function(path) {
  tmp <- tempfile(fileext = ".csv")
  system2("sh", c("-c", shQuote(sprintf(
    "sed '1s/^\\xEF\\xBB\\xBF//' %s | tr -d '\\r' | iconv -f UTF-8 -t UTF-8 -c > %s",
    shQuote(path), shQuote(tmp)))))
  out <- tryCatch(read.csv(tmp, stringsAsFactors = FALSE),
                  error = function(e) {
                    cat("  skip", basename(path), ":", conditionMessage(e), "\n")
                    NULL
                  })
  unlink(tmp); out
}

# normalise casper actor columns -> canonical schema (base R, returns data.frame)
norm <- function(d) {
  g <- function(col) if (col %in% names(d)) d[[col]] else rep(NA, nrow(d))
  data.frame(
    platform    = g("companyName"),
    review_id   = g("reviewId"),
    author      = g("reviewer"),
    country     = g("reviewersCountry"),
    title       = g("reviewTitle"),
    body        = g("reviewDescription"),
    rating      = suppressWarnings(as.integer(g("reviewRatingScore"))),
    date_posted = as.Date(substr(g("reviewDate"), 1, 10)),
    experience  = as.Date(substr(g("reviewDateOfExperience"), 1, 10)),
    verified    = g("isReviewVerified"),
    language    = g("reviewLanguage"),
    reply       = g("reviewCompanyResponse"),
    url         = g("reviewUrl"),
    stringsAsFactors = FALSE
  )
}

raw_list <- lapply(files, read_clean)
raw_list <- raw_list[!vapply(raw_list, is.null, logical(1))]
dat <- do.call(rbind, lapply(raw_list, norm))

# keep English reviews with real text, drop duplicate review IDs
keep <- !is.na(dat$body) & nchar(dat$body) >= 20 &
        (is.na(dat$language) | dat$language == "en")
dat <- dat[keep, ]
dat <- dat[!duplicated(dat$review_id), ]
dat$platform <- tolower(gsub("\\s+", "", dat$platform))

dir.create("data", showWarnings = FALSE)
out <- "data/trustpilot_reviews.csv"
write.csv(dat, out, row.names = FALSE)

cat("\nMerged ", nrow(dat), " unique English reviews -> ", out, "\n", sep = "")
cat("\nPer-platform:\n");       print(sort(table(dat$platform), decreasing = TRUE))
cat("\nRating distribution:\n");print(table(dat$rating, useNA = "ifany"))
cat("\nDate range:\n");         print(range(dat$date_posted, na.rm = TRUE))
cat("\nClass balance (>=4 positive, 3 neutral, <=2 negative):\n")
print(table(cut(dat$rating, c(0, 2, 3, 5),
                labels = c("negative", "neutral", "positive"))))
