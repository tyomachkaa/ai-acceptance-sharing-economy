# 05_clean_reddit.R
# -------------------------------------------------------------------
# Clean the off-topic noise out of reddit_targeted.csv so the Reddit
# corpus stays on the brief (AI in the sharing economy).
#
# Logic:
#   - DROP subreddits dominated by off-topic "AI replacing humans in
#     creative industries" debates (those drove the viral threads
#     that made up ~67% of the raw corpus).
#   - TAG every remaining comment with a `theme` column:
#       sharing_economy | ai_tech
#     so the downstream analysis can split or merge easily.
#
# Input  : data/reddit_targeted.csv  (~1,009 rows, raw v2 scrape)
# Output : data/reddit_clean.csv     (cleaned, themed)
# -------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
})

in_file  <- "data/reddit_targeted.csv"
out_file <- "data/reddit_clean.csv"

stopifnot(file.exists(in_file))

raw <- read.csv(in_file, stringsAsFactors = FALSE)

cat(sprintf("Input: %d rows | %d subreddits | %d threads\n",
            nrow(raw),
            length(unique(raw$subreddit)),
            length(unique(raw$url))))

# ---- subreddits dropped as off-topic ----
# Filmmakers + Entrepreneur together held the 3 viral threads
# (Roger Deakins, "they don't like movies", "Boring Business").
# Both are about AI-anxiety in creative/business careers, not rentals.
DROP_SUBS <- c("Filmmakers", "Entrepreneur")

# ---- taxonomy for `theme` column ----
SHARING_SUBS <- c(
  # stays / cars / RVs
  "AirBnB", "airbnb_hosts", "AirBnBHosts", "vrbo", "ShortTermRentals",
  "Hosting", "Turo", "RVing", "GoRVing", "gigwork", "couchsurfing",
  # equipment-rental adjacency
  "photography", "AskPhotography", "cinematography", "videography",
  "drones", "dronephotography", "DJI", "dji",
  "eventproduction", "EventProduction", "livesound"
)

clean <- raw |>
  filter(!tolower(subreddit) %in% tolower(DROP_SUBS)) |>
  mutate(theme = ifelse(tolower(subreddit) %in% tolower(SHARING_SUBS),
                        "sharing_economy", "ai_tech"))

cat(sprintf("\nAfter dropping subs [%s]:\n",
            paste(DROP_SUBS, collapse = ", ")))
cat(sprintf("  %d rows | %d subreddits | %d threads\n\n",
            nrow(clean),
            length(unique(clean$subreddit)),
            length(unique(clean$url))))

cat("---- Subreddit breakdown ----\n")
print(as.data.frame(clean |> count(subreddit, theme, sort = TRUE)))

cat("\n---- Theme split ----\n")
print(clean |> count(theme, name = "n_comments"))

cat("\n---- Top 15 threads ----\n")
print(clean |>
        count(thread_title, subreddit, sort = TRUE) |>
        slice_head(n = 15))

cat(sprintf("\nAvg comment length: %d chars\n",
            round(mean(nchar(clean$comment), na.rm = TRUE))))

write.csv(clean, out_file, row.names = FALSE)
cat(sprintf("\nWrote %s (%d rows)\n", out_file, nrow(clean)))
cat("Done.\n")
