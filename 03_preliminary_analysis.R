# prelim_analysis.R - quick exploratory pass for the coaching session.
# Base-R only so it runs anywhere. Produces 2 PNG figures + console summary.

rd <- read.csv("data/reddit_targeted_balanced.csv", stringsAsFactors = FALSE)
tp <- read.csv("data/trustpilot_reviews.csv",        stringsAsFactors = FALSE)

cat("================ CORPUS OVERVIEW ================\n")
cat(sprintf("Reddit (balanced): %4d comments | %2d subreddits | %s to %s\n",
            nrow(rd), length(unique(rd$subreddit)),
            min(as.Date(rd$date), na.rm = TRUE), max(as.Date(rd$date), na.rm = TRUE)))
cat(sprintf("Trustpilot:        %4d reviews  | %2d platforms  | %s to %s\n",
            nrow(tp), length(unique(tp$platform)),
            min(as.Date(tp$date_posted), na.rm = TRUE),
            max(as.Date(tp$date_posted), na.rm = TRUE)))
cat("\nTrustpilot per-platform:\n"); print(sort(table(tp$platform), decreasing = TRUE))

## ---- tokenizer ----
stop <- c("the","and","for","that","this","with","you","was","have","but","not","are",
"they","what","your","its","has","had","were","would","could","about","just","like",
"get","got","out","one","all","can","will","now","from","there","their","them","then",
"than","when","who","how","our","because","really","also","even","more","most","some",
"any","been","being","into","over","very","much","too","i","a","to","of","in","is","it",
"on","so","my","me","we","he","she","as","at","be","or","an","if","do","im","dont","ive",
"didnt","thats","car","cars")  # car/cars dropped: dominate Turo, not informative
tok <- function(x) {
  x <- tolower(paste(x, collapse = " "))
  x <- gsub("http[^ ]+", " ", x)
  x <- gsub("[^a-z ]", " ", x)
  w <- unlist(strsplit(x, "[[:space:]]+"))
  w[nchar(w) > 2 & !w %in% stop]
}
topw <- function(x, n = 15) head(sort(table(tok(x)), decreasing = TRUE), n)

cat("\n================ TOP 12 WORDS ================\n")
cat("\n-- Reddit: sharing-economy threads --\n");  print(topw(rd$comment[rd$theme == "sharing_economy"], 12))
cat("\n-- Reddit: AI/creative threads --\n");      print(topw(rd$comment[rd$theme == "ai_creative_tech"], 12))
cat("\n-- Trustpilot reviews --\n");               print(topw(tp$body, 12))

## ---- sentiment: mini-lexicon for Reddit, stars for Trustpilot ----
pos <- c("good","great","love","easy","best","amazing","excellent","helpful","nice","trust",
"recommend","perfect","awesome","happy","smooth","reliable","fast","friendly","worth","useful","convenient")
neg <- c("bad","worst","hate","hard","scam","problem","terrible","awful","horrible","wrong",
"broken","slow","useless","fail","frustrating","annoying","fake","disappointed","poor","refuse","cancel")
senti <- function(x) { w <- tok(x); (sum(w %in% pos) - sum(w %in% neg)) / max(1, length(w)) }

rd_se <- tapply(rd$comment, rd$theme, function(v) mean(vapply(v, senti, numeric(1))))
cat("\n================ SENTIMENT SIGNAL ================\n")
cat("Reddit mean polarity (mini-lexicon):\n"); print(round(rd_se, 4))
cat(sprintf("\nTrustpilot mean star rating: %.2f / 5  (n=%d)\n",
            mean(tp$rating, na.rm = TRUE), sum(!is.na(tp$rating))))
cat("Mean stars per platform:\n")
print(round(sort(tapply(tp$rating, tp$platform, mean, na.rm = TRUE)), 2))

## ---- FIGURE 1: top words, Reddit sharing-economy vs Trustpilot ----
png("figures/fig1_topwords.png", width = 1500, height = 700, res = 150)
par(mfrow = c(1, 2), mar = c(4, 7, 3, 1))
w1 <- rev(topw(rd$comment[rd$theme == "sharing_economy"], 12))
barplot(as.numeric(w1), names.arg = names(w1), horiz = TRUE, las = 1,
        col = "#1b9e77", main = "Reddit - sharing-economy", xlab = "count")
w2 <- rev(topw(tp$body, 12))
barplot(as.numeric(w2), names.arg = names(w2), horiz = TRUE, las = 1,
        col = "#7570b3", main = "Trustpilot - platform reviews", xlab = "count")
dev.off()

## ---- FIGURE 2: Trustpilot rating distribution per platform ----
png("figures/fig2_ratings.png", width = 1400, height = 700, res = 150)
par(mar = c(4, 5, 3, 1))
tb <- table(tp$platform, tp$rating)
barplot(t(tb), beside = FALSE, col = c("#d7191c","#fdae61","#ffffbf","#a6d96a","#1a9641"),
        las = 2, legend.text = paste(1:5, "star"),
        args.legend = list(x = "topright", cex = 0.8),
        main = "Trustpilot rating distribution by platform", ylab = "reviews")
dev.off()

cat("\nFigures written: figures/fig1_topwords.png, figures/fig2_ratings.png\n")
