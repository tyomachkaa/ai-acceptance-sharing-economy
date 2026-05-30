# compare_reddit_versions.R
# Compares the INITIAL Reddit scrape (keyword search across all of Reddit)
# with the V2 scrape (subreddit-targeted + per-thread cap).
# Produces console summary + 2 PNG figures. Base R only.

v1 <- read.csv("reddit_all.csv", stringsAsFactors = FALSE)                   # initial
v2 <- read.csv("data/reddit_targeted_balanced.csv", stringsAsFactors = FALSE) # targeted+balanced

v1$subreddit <- sub("^https://www\\.reddit\\.com/r/([^/]+)/.*$", "\\1", v1$url)

cat("================ SIZE & STRUCTURE ================\n")
cat(sprintf("v1 (keyword, all-Reddit): %5d comments | %2d threads | %2d subreddits\n",
            nrow(v1), length(unique(v1$url)), length(unique(v1$subreddit))))
cat(sprintf("v2 (subreddit-targeted):  %5d comments | %2d threads | %2d subreddits\n",
            nrow(v2), length(unique(v2$url)), length(unique(v2$subreddit))))

cat("\n================ TOP 8 SUBREDDITS ================\n")
cat("\nv1 (initial):\n"); print(head(sort(table(v1$subreddit), decreasing = TRUE), 8))
cat("\nv2 (targeted):\n"); print(head(sort(table(v2$subreddit), decreasing = TRUE), 8))

## ---- on-topic keyword coverage ----
kw <- c(AI = "\\bAI\\b", rental = "rental", rent = "\\brent",
        host = "\\bhost", `P2P brand` = "airbnb|turo|getaround|fatllama|outdoorsy",
        equipment = "drone|camera|lens|gear", trust = "\\btrust",
        `privacy/data` = "privacy|data")
cov <- function(d) sapply(kw, function(k)
  round(100 * sum(grepl(k, d$comment, ignore.case = TRUE)) / nrow(d), 1))
cmp <- data.frame(keyword = names(kw), v1 = cov(v1), v2 = cov(v2),
                  row.names = NULL)
cat("\n================ ON-TOPIC KEYWORD COVERAGE (%) ================\n")
print(cmp, row.names = FALSE)

## ---- FIGURE 1: keyword coverage v1 vs v2 ----
dir.create("figures", showWarnings = FALSE)
png("figures/fig_v1v2_keywords.png", width = 1500, height = 720, res = 150)
par(mar = c(4, 6, 3, 1))
m <- t(as.matrix(cmp[, c("v1", "v2")]))
colnames(m) <- cmp$keyword
barplot(m, beside = TRUE, horiz = TRUE, las = 1,
        col = c("#bdbdbd", "#1b9e77"),
        xlab = "% of comments containing term",
        main = "On-topic keyword coverage: initial vs v2 scrape")
legend("bottomright", c("v1 (keyword, all-Reddit)", "v2 (subreddit-targeted)"),
       fill = c("#bdbdbd", "#1b9e77"), bty = "n", cex = 0.9)
dev.off()

## ---- FIGURE 2: subreddit composition v1 vs v2 ----
png("figures/fig_v1v2_subreddits.png", width = 1600, height = 720, res = 150)
par(mfrow = c(1, 2), mar = c(4, 8, 3, 1))
b1 <- rev(head(sort(table(v1$subreddit), decreasing = TRUE), 8))
barplot(as.numeric(b1), names.arg = names(b1), horiz = TRUE, las = 1,
        col = "#bdbdbd", main = "v1: top subreddits (off-topic)",
        xlab = "comments")
b2 <- rev(head(sort(table(v2$subreddit), decreasing = TRUE), 8))
barplot(as.numeric(b2), names.arg = names(b2), horiz = TRUE, las = 1,
        col = "#1b9e77", main = "v2: top subreddits (on-topic)",
        xlab = "comments")
dev.off()

cat("\nFigures written: figures/fig_v1v2_keywords.png, figures/fig_v1v2_subreddits.png\n")

## ---- a single headline "on-topic share" metric ----
ontopic <- function(d) {
  hit <- grepl("airbnb|turo|getaround|fatllama|outdoorsy|\\bhost|\\brent|rental|sharing economy",
               d$comment, ignore.case = TRUE)
  round(100 * mean(hit), 1)
}
cat(sprintf("\nHeadline: comments mentioning sharing-economy terms -> v1 %.1f%%  vs  v2 %.1f%%\n",
            ontopic(v1), ontopic(v2)))
