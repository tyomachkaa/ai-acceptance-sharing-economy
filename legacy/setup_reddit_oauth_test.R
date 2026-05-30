# setup_reddit_oauth_test.R
# ----------------------------------------------------------------
# Quick (~5 second) test that your Reddit OAuth credentials work.
# Run this AFTER you've put REDDIT_CLIENT_ID / REDDIT_CLIENT_SECRET /
# REDDIT_USER_AGENT in .Renviron and restarted R.
#
# Pass criteria:
#   1. Token request returns 200 and an access_token.
#   2. One sample search on r/AirBnB returns >0 threads.
# ----------------------------------------------------------------

suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
})

UA   <- Sys.getenv("REDDIT_USER_AGENT")
CID  <- Sys.getenv("REDDIT_CLIENT_ID")
CSEC <- Sys.getenv("REDDIT_CLIENT_SECRET")

if (!nzchar(UA) || !nzchar(CID) || !nzchar(CSEC)) {
  stop("Missing env vars. Check .Renviron and restart R.\n",
       "  REDDIT_CLIENT_ID = ",     ifelse(nzchar(CID),  "OK", "MISSING"), "\n",
       "  REDDIT_CLIENT_SECRET = ", ifelse(nzchar(CSEC), "OK", "MISSING"), "\n",
       "  REDDIT_USER_AGENT = ",    ifelse(nzchar(UA),   "OK", "MISSING"))
}

cat("Env vars look OK.\n")
cat("  User-Agent:", UA, "\n")
cat("  client_id:", substr(CID, 1, 4), "...(", nchar(CID), " chars)\n", sep = "")
cat("  secret   :", substr(CSEC, 1, 4), "...(", nchar(CSEC), " chars)\n\n", sep = "")

# Step 1: get token
cat("[1] Requesting OAuth token from reddit.com/api/v1/access_token ...\n")
resp <- POST(
  "https://www.reddit.com/api/v1/access_token",
  authenticate(CID, CSEC),
  body = list(grant_type = "client_credentials"),
  encode = "form",
  user_agent(UA)
)
cat("    HTTP", status_code(resp), "\n")
if (status_code(resp) != 200) {
  cat("    Body:", substr(content(resp, "text"), 1, 300), "\n")
  stop("OAuth failed. Double-check client_id and client_secret in .Renviron.")
}
tok <- content(resp)$access_token
stopifnot(!is.null(tok))
cat("    Got access_token (", nchar(tok), " chars). \xe2\x9c\x93\n\n", sep = "")

# Step 2: sample search
cat("[2] Sample search: r/AirBnB for 'AI' ...\n")
resp2 <- GET(
  "https://oauth.reddit.com/r/AirBnB/search?q=AI&restrict_sr=on&sort=top&t=all&limit=5",
  add_headers(Authorization = paste("Bearer", tok)),
  user_agent(UA),
  timeout(15)
)
cat("    HTTP", status_code(resp2), "\n")
if (status_code(resp2) != 200) {
  cat("    Body:", substr(content(resp2, "text"), 1, 300), "\n")
  stop("Search call failed.")
}
js <- fromJSON(content(resp2, as = "text", encoding = "UTF-8"),
               simplifyVector = FALSE)
n_hits <- length(js$data$children)
cat("    Returned", n_hits, "threads. \xe2\x9c\x93\n\n", sep = " ")

if (n_hits == 0) {
  warning("OAuth works but search returned 0 threads. ",
          "Subreddit may be quarantined or the keyword too narrow.")
} else {
  cat("Sample titles:\n")
  for (i in seq_len(min(3, n_hits))) {
    d <- js$data$children[[i]]$data
    cat("  -", substr(d$title, 1, 80), " (", d$num_comments, " comments)\n", sep = "")
  }
  cat("\nAll good. You can now run:\n")
  cat("  Rscript 01b_scrape_reddit_deep.R\n")
}
