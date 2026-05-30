# =============================================================================
# FINAL PROJECT – Phase 1: Data Collection via Reddit
# Topic: AI Acceptance in the Sharing Economy
# =============================================================================
# This script scrapes Reddit for posts and comments about AI agents on
# peer-to-peer rental platforms (cameras, drones, event tech).
# We collect TWO classes of text:
#   Class A — Positive / trusting attitudes toward AI
#   Class B — Negative / skeptical attitudes toward AI
# =============================================================================


# -----------------------------------------------------------------------------
# STEP 0: Install and load the package
# -----------------------------------------------------------------------------
# RedditExtractoR lets R search Reddit and download thread content — no 
# browser needed, no API key required. The if(!require()) pattern installs 
# it only if it is not already on your machine.

if (!require("RedditExtractoR")) install.packages("RedditExtractoR")
library(RedditExtractoR)


# -----------------------------------------------------------------------------
# STEP 1A: Search Reddit — CLASS A (Positive / Trusting)
# -----------------------------------------------------------------------------
# find_thread_urls() sends a search to Reddit and returns a data frame where
# each row is one matching thread. Columns include the thread URL, title,
# subreddit name, upvote count, and number of comments.
#
# keywords = your search term — Reddit searches titles and post bodies
# sort_by  = "relevance" returns the most topic-relevant threads first
# period   = "all" searches across all of Reddit history (not just recent)

urls_positive <- find_thread_urls(
  keywords = "AI rental platform helpful automation trust",
  sort_by  = "relevance",
  period   = "all"
)

# Always inspect what came back before downloading content.
# Check the 'title' and 'subreddit' columns to see if results look on-topic.
head(urls_positive)
nrow(urls_positive)  # how many threads were found in total


# -----------------------------------------------------------------------------
# STEP 1B: Search Reddit — CLASS B (Negative / Skeptical)
# -----------------------------------------------------------------------------

urls_negative <- find_thread_urls(
  keywords = "AI rental platform problems distrust concerns",
  sort_by  = "relevance",
  period   = "all"
)

head(urls_negative)
nrow(urls_negative)


# -----------------------------------------------------------------------------
# STEP 2: Download thread content — comments are your main text
# -----------------------------------------------------------------------------
# get_thread_content() visits each URL and downloads the full thread.
# It returns a LIST with two elements:
#   $threads  — one row per thread (post title + body text)
#   $comments — one row per user comment across all threads
#
# We use [1:30] to limit to the first 30 threads — a safe number that
# balances data volume against scraping time (roughly 5–10 minutes).
# Increase to [1:40] if you want more data, but don't exceed 50 at once.

# --- Class A ---
data_positive <- get_thread_content(urls_positive$url[1:30])

threads_positive  <- data_positive$threads   # post-level data
comments_positive <- data_positive$comments  # comment-level data (use this)

# Quick check: how many comments did we get?
nrow(comments_positive)
head(comments_positive$comment)  # preview the actual text


# --- Class B ---
data_negative <- get_thread_content(urls_negative$url[1:30])

threads_negative  <- data_negative$threads
comments_negative <- data_negative$comments

nrow(comments_negative)
head(comments_negative$comment)


# -----------------------------------------------------------------------------
# STEP 3: Add a class label to each dataset
# -----------------------------------------------------------------------------
# Before combining, we label each row so we always know which class it belongs
# to. This 'class' column will be essential for all comparisons later.

comments_positive$class <- "positive"   # label every row in Class A
comments_negative$class <- "negative"   # label every row in Class B


# -----------------------------------------------------------------------------
# STEP 4: Combine into one master dataset
# -----------------------------------------------------------------------------
# rbind() stacks two data frames on top of each other (they must have the
# same column names, which they do since both come from RedditExtractoR).

all_comments <- rbind(comments_positive, comments_negative)

# Sanity check: confirm row counts and class balance
nrow(all_comments)
table(all_comments$class)   # should show roughly similar numbers per class


# -----------------------------------------------------------------------------
# STEP 5: Save to CSV — do this immediately after scraping
# -----------------------------------------------------------------------------
# Saving right away means you don't have to re-scrape if R crashes or 
# the session ends. Load from CSV in all future scripts instead of scraping again.

write.csv(comments_positive, "reddit_positive.csv", row.names = FALSE)
write.csv(comments_negative, "reddit_negative.csv", row.names = FALSE)
write.csv(all_comments,      "reddit_all.csv",      row.names = FALSE)

# Confirmation message
cat("Scraping complete!\n")
cat("Total comments collected:", nrow(all_comments), "\n")
cat("Class A (positive):", sum(all_comments$class == "positive"), "\n")
cat("Class B (negative):", sum(all_comments$class == "negative"), "\n")