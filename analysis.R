# ============================================================================
# analysis.R   AI Acceptance Across Service Platforms
# ----------------------------------------------------------------------------
# THE project analysis pipeline. Run after data collection (01, 02, 06).
# It combines the Reddit text mining and the Reddit-vs-Trustpilot integration
# into one script.
#
#   Reddit      = discussion baseline   -> deep text mining (steps 1-7)
#   Trustpilot  = star-labelled reviews -> verification layer (steps 8-10)
#
# Steps (the report explains each one in the same order):
#   1  Preprocess + two classes      clean, lemmatise, positive/negative split
#   2  Word frequency                top-10 words per class (bar chart)
#   3  Word clouds                   commonality + comparison (1- and 2-gram)
#   4  Sentiment (emotions)          NRC 8 emotions, both classes, one chart
#   5  Co-occurrence network         bigram word network (igraph)
#   6  Topic modelling (LDA)         4 topics per class, 1- and 2-gram
#   7  Word embeddings (GloVe)       semantic neighbours of key terms
#   8  Validation vs real stars      do inferred classes match Trustpilot stars?
#   9  Themes + AI-role gradient     shared frustrations; product/add-on/support
#  10  Strategic recommendations     the table the report turns into advice
#
# Lexicons: Bing (bundled with tidytext) for the positive/negative split;
#           NRC (bundled with syuzhet) for the 8 emotions. No downloads.
# Outputs:  figures/*.png  and  outputs/*.csv  (consumed live by report.Rmd)
# ============================================================================

suppressWarnings(suppressMessages({
  library(dplyr); library(stringr); library(tidyr); library(tidytext)
  library(ggplot2); library(scales); library(textstem)
  library(wordcloud); library(RColorBrewer); library(igraph); library(ggraph)
  library(topicmodels); library(text2vec); library(syuzhet)
}))
set.seed(42)
# We save every figure explicitly with ggsave()/png(); send any auto-printed
# plot to a throwaway device so a default Rplots.pdf is never opened.
options(device = function(...) grDevices::png(tempfile(fileext = ".png")))
dir.create("figures", showWarnings = FALSE)
dir.create("outputs", showWarnings = FALSE)
theme_set(theme_minimal(base_size = 12))

# ---- small helpers ---------------------------------------------------------
clean_text <- function(x) {                       # standard text normalisation
  x <- tolower(ifelse(is.na(x), "", as.character(x)))
  x <- str_replace_all(x, "http\\S+|www\\.\\S+", " ")   # links
  x <- str_replace_all(x, "&amp;", "and")
  x <- str_replace_all(x, "/?u/\\w+|/?r/\\w+", " ")      # /u/ and /r/ handles
  x <- str_replace_all(x, "[^a-z ]", " ")               # punctuation + numbers
  str_squish(x)
}
extra_stop <- c(
  # generic filler
  "get","like","just","one","can","will","thing","really","lol","also","even",
  "much","make","got","know","want","use","way","actually","lot","thing","still",
  # contraction fragments left after punctuation is stripped
  "dont","im","ive","youre","thats","gonna","wanna","cant","didnt","doesnt",
  "don","doesn","didn","isn","wasn","couldn","wouldn","shouldn","aren","won",
  "ve","ll","re","st","amp"," on",
  # Reddit auto-moderator / boilerplate (one bot message repeated thousands of times)
  "moderator","compose","subreddit","remember","respectful","civil","perform",
  "action","automatically","karma","beep","boop","rope","autopost","removed",
  "deleted","apologize","inconvenience","post")

# Six AI-acceptance themes, one regex set, applied to BOTH corpora so Reddit
# and Trustpilot are comparable on the same vocabulary.
THEMES <- list(
  automation_vs_human = c("\\bbot\\b","chatbot","automat","robot","algorithm",
                          "\\bai\\b","no human","real person","speak to (a )?human",
                          "talk to (a )?human","machine"),
  trust_safety        = c("trust","scam","fraud","safe","secur","verif","privacy",
                          "personal data","reliab","legit","sketchy"),
  pricing_fees        = c("price","pricing","\\bfee","charge","refund","deposit",
                          "\\bcost","expensive","overcharg","billing"),
  accuracy_quality    = c("wrong","error","mistake","inaccurat","hallucinat",
                          "useless","broken","glitch","fail","accuracy","quality"),
  support_resolution  = c("support","\\bhelp","resolve","resolution","ticket",
                          "respon","\\bwait","contact","customer service","escalat"),
  anthro_companion    = c("friend","companion","personality","\\bfeel","emotion",
                          "lonely","human.?like","conversation","character","empath")
)
theme_labels <- c(automation_vs_human = "Automation vs. human",
                  trust_safety = "Trust & safety", pricing_fees = "Pricing & fees",
                  accuracy_quality = "Accuracy & quality",
                  support_resolution = "Support & resolution",
                  anthro_companion = "Anthropomorphism")
tag_themes <- function(text) {
  low <- tolower(ifelse(is.na(text), "", as.character(text)))
  as.data.frame(lapply(THEMES, function(p)
    str_detect(low, regex(paste(p, collapse = "|"), ignore_case = TRUE))))
}

# ============================================================================
# STEP 1  Preprocessing + the two classes
# Why: text models need normalised tokens; the brief asks for a per-class
# comparison, so we split comments into positive vs negative using the Bing
# opinion lexicon (sum of +1/-1 word polarities, then the sign).
# ============================================================================
cat("STEP 1  Preprocessing + classes\n")
reddit <- read.csv("data/reddit_baseline.csv", stringsAsFactors = FALSE) |>
  mutate(doc_id = row_number()) |>
  filter(!is.na(body), str_squish(body) != "")
reddit$clean <- lemmatize_strings(clean_text(reddit$body))   # lemmatise to base words

bing <- get_sentiments("bing") |>
  mutate(value = ifelse(sentiment == "positive", 1L, -1L))

scores <- reddit |> select(doc_id, clean) |>
  unnest_tokens(word, clean) |>
  inner_join(bing, by = "word") |>
  group_by(doc_id) |> summarise(s = sum(value), .groups = "drop")

reddit <- reddit |> left_join(scores, by = "doc_id") |>
  mutate(s = coalesce(s, 0L),
         class = case_when(s > 0 ~ "positive", s < 0 ~ "negative",
                           TRUE ~ "neutral"))
cat("  class balance:\n"); print(table(reddit$class))

reddit2 <- reddit |> filter(class %in% c("positive", "negative"))

tokens_uni <- reddit2 |> select(doc_id, class, platform_category, clean) |>
  unnest_tokens(word, clean) |>
  filter(!word %in% stop_words$word, !word %in% extra_stop, str_length(word) > 2)

tokens_bi <- reddit2 |> select(doc_id, class, platform_category, clean) |>
  unnest_tokens(bigram, clean, token = "ngrams", n = 2) |>
  filter(!is.na(bigram)) |>
  separate(bigram, c("w1", "w2"), sep = " ") |>
  filter(!w1 %in% stop_words$word, !w2 %in% stop_words$word,
         !w1 %in% extra_stop, !w2 %in% extra_stop,
         str_length(w1) > 2, str_length(w2) > 2) |>
  unite(bigram, w1, w2, sep = " ")

# ============================================================================
# STEP 2  Word frequency: top-10 words per class
# Why: the fastest read on what each class talks about; a bar chart makes the
# two classes directly comparable.
# ============================================================================
cat("STEP 2  Top words per class\n")
top_words <- tokens_uni |> count(class, word, sort = TRUE) |>
  group_by(class) |> slice_max(n, n = 10, with_ties = FALSE) |> ungroup()
write.csv(top_words, "outputs/top_words.csv", row.names = FALSE)

ggplot(top_words, aes(reorder_within(word, n, class), n, fill = class)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~class, scales = "free_y") +
  scale_x_reordered() + coord_flip() +
  scale_fill_manual(values = c(positive = "#41ab5d", negative = "#e6550d")) +
  labs(title = "Top 10 words per class", x = NULL, y = "Word count")
ggsave("figures/fig_01_top_words.png", width = 9, height = 4.6, dpi = 150)

# ============================================================================
# STEP 3  Word clouds: commonality + comparison (1- and 2-gram)
# Why: clouds show the shared vocabulary (commonality) and the words that most
# distinguish the two classes (comparison) at a glance, good for a slide.
# ============================================================================
cat("STEP 3  Word clouds\n")
to_matrix <- function(df, term) {
  m <- df |> count(class, .data[[term]]) |>
    pivot_wider(names_from = class, values_from = n, values_fill = 0) |>
    as.data.frame()
  rn <- m[[term]]; m[[term]] <- NULL; m <- as.matrix(m); rownames(m) <- rn; m
}
uni_mat <- to_matrix(tokens_uni, "word")
bi_mat  <- to_matrix(tokens_bi,  "bigram")

png("figures/fig_02_commonality_cloud.png", width = 1400, height = 1100, res = 200)
commonality.cloud(uni_mat, max.words = 120, random.order = FALSE,
                  colors = brewer.pal(6, "Dark2"))
dev.off()
png("figures/fig_03_comparison_cloud.png", width = 1500, height = 1100, res = 200)
comparison.cloud(uni_mat, max.words = 120, random.order = FALSE, title.size = 1.4,
                 colors = c("#e6550d", "#41ab5d"))
dev.off()
png("figures/fig_04_comparison_cloud_bigram.png", width = 1500, height = 1100, res = 200)
comparison.cloud(bi_mat, max.words = 70, random.order = FALSE, title.size = 1.4,
                 colors = c("#e6550d", "#41ab5d"))
dev.off()

# ============================================================================
# STEP 4  Sentiment: NRC 8 emotions, both classes on one chart
# Why: the classes are split by polarity, so to add information we look at the
# emotional texture (anger, trust, joy, ...) and how the two classes diverge.
# ============================================================================
cat("STEP 4  NRC emotions per class (sampled for speed)\n")
samp <- function(v, n = 1200) if (length(v) > n) sample(v, n) else v
emo_one <- function(txt) {
  e <- get_nrc_sentiment(txt)
  e[, c("anger","anticipation","disgust","fear","joy","sadness","surprise","trust")]
}
ep <- emo_one(samp(reddit2$body[reddit2$class == "positive"]))
en <- emo_one(samp(reddit2$body[reddit2$class == "negative"]))
nrc <- bind_rows(
  data.frame(class = "positive", emotion = names(ep), score = colMeans(ep)),
  data.frame(class = "negative", emotion = names(en), score = colMeans(en)))
write.csv(nrc, "outputs/nrc_by_class.csv", row.names = FALSE)

ggplot(nrc, aes(reorder(emotion, score), score, fill = class)) +
  geom_col(position = "dodge") + coord_flip() +
  scale_fill_manual(values = c(positive = "#41ab5d", negative = "#e6550d")) +
  labs(title = "Emotional texture by class (NRC)", x = NULL,
       y = "Average emotion words per comment", fill = "Class")
ggsave("figures/fig_05_sentiment_nrc.png", width = 8, height = 4.6, dpi = 150)

# ============================================================================
# STEP 5  Word co-occurrence network (bigrams)
# Why: frequency lists lose structure; a network shows which words travel
# together, revealing the phrases users actually use ("customer service", ...).
# ============================================================================
cat("STEP 5  Co-occurrence network\n")
pair_counts <- tokens_bi |> separate(bigram, c("w1", "w2"), sep = " ") |>
  count(w1, w2, sort = TRUE) |> rename(weight = n)
net <- pair_counts |> filter(weight >= 10) |> slice_max(weight, n = 90) |>
  graph_from_data_frame(directed = FALSE)
net <- delete_vertices(net, V(net)[degree(net) < 2])   # drop isolated word pairs
V(net)$deg <- degree(net)

set.seed(42)
p_net <- ggraph(net, layout = "fr") +
  geom_edge_link(aes(width = weight), colour = "grey75", alpha = 0.6, show.legend = FALSE) +
  geom_node_point(aes(size = deg), colour = "#2c7fb8", show.legend = FALSE) +
  geom_node_text(aes(label = name), repel = TRUE, size = 3.3,
                 max.overlaps = 30, segment.colour = "grey80") +
  scale_edge_width(range = c(0.3, 2.2)) + scale_size(range = c(2, 7)) +
  labs(title = "Word co-occurrence network (Reddit bigrams)",
       subtitle = "Connected core of the strongest word pairs") +
  theme_void(base_size = 12)
ggsave("figures/fig_06_network.png", p_net, width = 9, height = 6.5, dpi = 150)

# ============================================================================
# STEP 6  Topic modelling (LDA): 4 topics per class, 1- and 2-gram
# Why: topics group co-occurring words into latent themes, summarising thousands
# of comments into a handful of interpretable subjects per class.
# ============================================================================
cat("STEP 6  LDA topics\n")
fit_lda <- function(d, term, k = 4, sparse = 0.99) {
  dtm <- d |> count(doc_id, !!sym(term)) |> cast_dtm(doc_id, !!sym(term), n)
  dtm <- tm::removeSparseTerms(dtm, sparse)
  dtm <- dtm[slam::row_sums(dtm) > 0, ]
  LDA(dtm, k = k, method = "Gibbs",
      control = list(seed = 42, burnin = 300, iter = 500, alpha = 0.5))
}
top_terms <- function(m, n = 8) as.data.frame(t(apply(
  terms(m, n), 2, function(x) x)))

lda_pos <- fit_lda(tokens_uni |> filter(class == "positive"), "word")
lda_neg <- fit_lda(tokens_uni |> filter(class == "negative"), "word")
lda_pos_bi <- fit_lda(tokens_bi |> filter(class == "positive"), "bigram", sparse = 0.995)
lda_neg_bi <- fit_lda(tokens_bi |> filter(class == "negative"), "bigram", sparse = 0.995)

write.csv(as.data.frame(terms(lda_pos, 8)), "outputs/lda_positive_unigram.csv", row.names = FALSE)
write.csv(as.data.frame(terms(lda_neg, 8)), "outputs/lda_negative_unigram.csv", row.names = FALSE)
write.csv(as.data.frame(terms(lda_pos_bi, 6)), "outputs/lda_positive_bigram.csv", row.names = FALSE)
write.csv(as.data.frame(terms(lda_neg_bi, 6)), "outputs/lda_negative_bigram.csv", row.names = FALSE)

# Hero figure: per-topic top terms for the negative class (where design lessons live)
beta_plot <- tidy(lda_neg, matrix = "beta") |>
  group_by(topic) |> slice_max(beta, n = 7, with_ties = FALSE) |> ungroup() |>
  mutate(topic = paste("Topic", topic))
ggplot(beta_plot, aes(reorder_within(term, beta, topic), beta, fill = factor(topic))) +
  geom_col(show.legend = FALSE) + facet_wrap(~topic, scales = "free_y") +
  scale_x_reordered() + coord_flip() +
  labs(title = "LDA topics, negative class (Reddit)", x = NULL, y = "Term weight (beta)")
ggsave("figures/fig_07_lda_negative.png", width = 9, height = 5.4, dpi = 150)

# ============================================================================
# STEP 7  Word embeddings (GloVe): semantic neighbours of key terms
# Why: lexicon/topic methods ignore meaning; embeddings place words in a vector
# space so we can read what "trust", "bot", "human" sit next to in this corpus.
# ============================================================================
cat("STEP 7  GloVe embeddings\n")
# Train on the already-cleaned tokens (lemmatised, no stopwords, length > 2)
# so the vector space is not polluted by 1-2 character fragments.
glove_docs <- tokens_uni |> group_by(doc_id) |>
  summarise(txt = paste(word, collapse = " "), .groups = "drop")
it <- itoken(space_tokenizer(glove_docs$txt), progressbar = FALSE)
vocab <- create_vocabulary(it) |> prune_vocabulary(term_count_min = 10)
vzr <- vocab_vectorizer(vocab)
tcm <- create_tcm(it, vzr, skip_grams_window = 6)
glove <- GlobalVectors$new(rank = 50, x_max = 10)
wv <- glove$fit_transform(tcm, n_iter = 30, progressbar = FALSE)
word_vectors <- wv + t(glove$components)

neighbours <- function(w, n = 8) {
  if (!w %in% rownames(word_vectors)) return(rep(NA, n))
  sims <- sim2(word_vectors, word_vectors[w, , drop = FALSE],
               method = "cosine", norm = "l2")[, 1]
  names(head(sort(sims, decreasing = TRUE), n + 1)[-1])
}
keys <- c("trust", "bot", "human", "host", "automate")
nb <- lapply(keys, neighbours)
nb_df <- data.frame(term = keys,
                    neighbours = sapply(nb, function(x) paste(x, collapse = ", ")))
write.csv(nb_df, "outputs/embeddings_neighbours.csv", row.names = FALSE)
print(nb_df)

# ============================================================================
# STEP 8  Validation: do the inferred classes match real Trustpilot stars?
# Why: Reddit has no ground-truth label, so we INFER the class from sentiment.
# Trustpilot has both text and a 1-5 star rating, so it is where we can test
# whether the inference is trustworthy before reading the two corpora together.
# ============================================================================
cat("STEP 8  Validation vs Trustpilot stars\n")
tp <- read.csv("data/trustpilot_flagged.csv", stringsAsFactors = FALSE) |>
  mutate(doc_id = row_number(),
         text = str_squish(paste(ifelse(is.na(title), "", title),
                                 ifelse(is.na(body), "", body))),
         rating = suppressWarnings(as.numeric(rating)),
         ai_related = as.logical(ai_related)) |>
  filter(text != "", !is.na(rating))
tp$clean <- clean_text(tp$text)

tp_scores <- tp |> select(doc_id, clean) |> unnest_tokens(word, clean) |>
  inner_join(bing, by = "word") |>
  group_by(doc_id) |> summarise(s = sum(value), .groups = "drop")
tp <- tp |> left_join(tp_scores, by = "doc_id") |>
  mutate(s = coalesce(s, 0L),
         lex_class  = case_when(s > 0 ~ "positive", s < 0 ~ "negative", TRUE ~ "neutral"),
         star_class = case_when(rating >= 4 ~ "positive", rating <= 2 ~ "negative", TRUE ~ "neutral"))

val <- tp |> filter(lex_class != "neutral", star_class != "neutral")
conf <- val |> count(star_class, lex_class) |>
  pivot_wider(names_from = lex_class, values_from = n, values_fill = 0)
agreement <- mean(val$star_class == val$lex_class)
kt <- table(val$star_class, val$lex_class)
po <- sum(diag(kt)) / sum(kt)
pe <- sum(rowSums(kt) * colSums(kt)) / sum(kt)^2
kappa <- (po - pe) / (1 - pe)
cat(sprintf("  agreement %.1f%%  kappa %.2f  (n=%d)\n", 100*agreement, kappa, nrow(val)))
write.csv(conf, "outputs/validity_confusion.csv", row.names = FALSE)

val |> count(star_class, lex_class) |> group_by(star_class) |>
  mutate(prop = n / sum(n)) |> ungroup() |>
  ggplot(aes(lex_class, star_class, fill = prop)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = sprintf("%d\n%.0f%%", n, 100*prop)), size = 4.2) +
  scale_fill_gradient(low = "#f2f7fb", high = "#2c7fb8", labels = percent) +
  labs(title = "Inferred class vs. real star rating (Trustpilot)",
       subtitle = sprintf("%.0f%% agreement, kappa = %.2f", 100*agreement, kappa),
       x = "Sentiment-inferred class (the Reddit method)",
       y = "Star-based class (ground truth)", fill = "Row share")
ggsave("figures/fig_08_validity.png", width = 7, height = 4.6, dpi = 150)

# ============================================================================
# STEP 9  Shared themes + the AI-role gradient
# Why: with the method validated, tag both corpora with the same six themes to
# see which frustrations are robust across sources, then measure how acceptance
# changes with AI's role (product vs add-on vs support desk).
# ============================================================================
cat("STEP 9  Themes + AI-role gradient\n")
r_th <- bind_cols(reddit2 |> transmute(source = "Reddit", class),
                  tag_themes(reddit2$body))
t_th <- bind_cols(tp |> filter(star_class %in% c("positive","negative")) |>
                    transmute(source = "Trustpilot", class = star_class),
                  tag_themes(tp$text[tp$star_class %in% c("positive","negative")]))
theme_long <- bind_rows(r_th, t_th) |>
  pivot_longer(all_of(names(THEMES)), names_to = "theme", values_to = "hit") |>
  group_by(source, class, theme) |>
  summarise(prevalence = mean(hit), .groups = "drop") |>
  mutate(theme_label = theme_labels[theme])
write.csv(theme_long, "outputs/theme_prevalence.csv", row.names = FALSE)

ggplot(theme_long, aes(reorder(theme_label, prevalence), prevalence, fill = class)) +
  geom_col(position = "dodge") + coord_flip() + facet_wrap(~source) +
  scale_y_continuous(labels = percent) +
  scale_fill_manual(values = c(positive = "#41ab5d", negative = "#e6550d")) +
  labs(title = "AI-acceptance themes by class and source", x = NULL,
       y = "Share mentioning theme", fill = "Class")
ggsave("figures/fig_09_themes.png", width = 9, height = 5, dpi = 150)

drivers <- theme_long |> select(source, class, theme, theme_label, prevalence) |>
  pivot_wider(names_from = class, values_from = prevalence) |>
  mutate(lift = negative / positive)
drivers_wide <- drivers |> select(theme, theme_label, source, lift) |>
  pivot_wider(names_from = source, values_from = lift) |>
  mutate(cross_validated = (Reddit > 1) & (Trustpilot > 1)) |>
  arrange(desc((Reddit + Trustpilot) / 2))
write.csv(drivers_wide, "outputs/negativity_drivers_wide.csv", row.names = FALSE)
print(drivers_wide)

ggplot(drivers, aes(reorder(theme_label, lift), lift, fill = source)) +
  geom_col(position = "dodge") +
  geom_hline(yintercept = 1, linetype = "dashed", colour = "grey30") +
  coord_flip() +
  scale_fill_manual(values = c(Reddit = "#756bb1", Trustpilot = "#2c7fb8")) +
  labs(title = "What drives the negative class",
       subtitle = "Lift above 1 means the theme is more common in negative text",
       x = NULL, y = "Negative / positive prevalence (lift)", fill = "Source")
ggsave("figures/fig_10_drivers.png", width = 9, height = 5, dpi = 150)

# AI-role gradient (Reddit % positive by context)
reddit_grad <- reddit2 |> group_by(platform_category) |>
  summarise(n = n(), pct_positive = mean(class == "positive"), .groups = "drop")
write.csv(reddit_grad, "outputs/role_gradient.csv", row.names = FALSE)

# AI / automation penalty (Trustpilot stars)
penalty <- tp |> filter(!is.na(ai_related)) |> group_by(ai_related) |>
  summarise(n = n(), mean_rating = mean(rating), .groups = "drop")
ai_star  <- penalty$mean_rating[penalty$ai_related == TRUE]
non_star <- penalty$mean_rating[penalty$ai_related == FALSE]
write.csv(penalty, "outputs/ai_penalty.csv", row.names = FALSE)
cat(sprintf("  AI reviews %.2f stars vs %.2f for the rest\n", ai_star, non_star))

penalty |> mutate(label = ifelse(ai_related, "Mentions AI / automation", "No AI mention")) |>
  ggplot(aes(reorder(label, mean_rating), mean_rating, fill = ai_related)) +
  geom_col(width = 0.6, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.2f", mean_rating)), vjust = -0.3, size = 4.5) +
  scale_fill_manual(values = c(`TRUE` = "#e6550d", `FALSE` = "#41ab5d")) +
  ylim(0, 5) +
  labs(title = "The AI / automation penalty (Trustpilot)",
       x = NULL, y = "Mean star rating (1-5)")
ggsave("figures/fig_11_ai_penalty.png", width = 6.5, height = 4.4, dpi = 150)

# ============================================================================
# STEP 10  Strategic recommendations table
# Why: turn the evidence above into a short, ordered list of design rules the
# report and presentation can state directly.
# ============================================================================
cat("STEP 10  Strategic recommendations\n")
recommendations <- tibble::tribble(
  ~priority, ~recommendation,                         ~evidence,
  1, "Keep a human one click away",                   "Automation / 'no human' is the strongest marker of negative reviews (8x on Trustpilot) and the top negative topic on Reddit.",
  2, "Disclose the AI and admit its limits",          "Accuracy and 'doesn't work' complaints separate the classes most cleanly (negative class 1.8x on Reddit, 6.9x on Trustpilot).",
  3, "Optimise for first-contact resolution",         "Support and resolution language drives the negative class in both sources (1.2x Reddit, 1.8x Trustpilot).",
  4, "Match the persona to the role",                 "Anthropomorphism is welcomed when AI IS the product but reads as cold in transactions; Reddit is most positive for AI-native, least for rentals.",
  5, "Show all-in price and refund rules up front",   "Pricing and fees dominate negative rental reviews (5.4x on Trustpilot); a rental-specific, not AI-specific, frustration."
)
write.csv(recommendations, "outputs/strategic_recommendations.csv", row.names = FALSE)

# Class-difference summary (the report's "key differences" slide)
class_diff <- theme_long |>
  filter(source == "Reddit") |>
  select(theme_label, class, prevalence) |>
  pivot_wider(names_from = class, values_from = prevalence) |>
  mutate(leans = ifelse(negative > positive, "negative", "positive")) |>
  arrange(desc(abs(negative - positive)))
write.csv(class_diff, "outputs/class_differences.csv", row.names = FALSE)

# ---- headline metrics for the report --------------------------------------
metrics <- tibble::tribble(
  ~metric, ~value,
  "reddit_n", as.character(nrow(reddit)),
  "reddit_pos", as.character(sum(reddit$class == "positive")),
  "reddit_neg", as.character(sum(reddit$class == "negative")),
  "tp_n", as.character(nrow(tp)),
  "validity_agreement_pct", sprintf("%.1f", 100*agreement),
  "validity_kappa", sprintf("%.2f", kappa),
  "validity_n", as.character(nrow(val)),
  "ai_star", sprintf("%.2f", ai_star),
  "non_ai_star", sprintf("%.2f", non_star),
  "ai_penalty", sprintf("%.2f", non_star - ai_star),
  "n_cross_drivers", as.character(sum(drivers_wide$cross_validated, na.rm = TRUE))
)
write.csv(metrics, "outputs/metrics.csv", row.names = FALSE)

cat("\nDONE. figures/ has 11 PNGs; outputs/ has the CSV tables for report.Rmd\n")
