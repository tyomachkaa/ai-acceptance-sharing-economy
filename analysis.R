set.seed(1)

# Project: AI Acceptance Across Service Platforms

# STEP 1  Preprocessing      clean text + build the two classes (pos/neg)
# STEP 2  Exploratory        top-10 words per class + word clouds
# STEP 3  Structural+Sent.   co-occurrence network + sentiment comparison
# STEP 4  Modeling           LDA topics per class + GloVe embeddings
#
# Two classes  = positive vs negative (from AFINN sentiment score)
# Second lens  = platform_category (ai_service / rental / customer_service)
# Data         = data/reddit_baseline.csv  (text in `body`)


#Run packages
library(dplyr)
library(stringr)
library(tidyr)
library(readr)
library(tidytext)
library(tm)
library(textstem)
library(ggplot2)
library(wordcloud)
library(reshape2)
library(igraph)
library(topicmodels)
library(syuzhet)
library(text2vec)


# 1. Dataset & Preprocessing

# Load data; keep needed columns; give each comment an ID; drop empties.
reddit <- read_csv("data/reddit_baseline.csv", show_col_types = FALSE) %>%
  mutate(doc_id = row_number()) %>%
  select(doc_id, subreddit, platform_category, source_query, date, body) %>%
  filter(!is.na(body), str_squish(body) != "")

# Pre-clean Reddit-specific junk before the standard cleaners.
reddit <- reddit %>%
  mutate(raw = body,
         raw = str_replace_all(raw, "http\\S+|www\\.\\S+", " "),  # links
         raw = str_replace_all(raw, "&amp;", "and"),
         raw = str_replace_all(raw, "[\r\n]+", " "),
         raw = str_replace_all(raw, "/?u/\\w+|/?r/\\w+", " "))     # /u/ /r/

# Standard cleaning pipeline: lowercase -> stopwords -> punctuation ->
# numbers -> lemmatise (base form) -> tidy spacing.
corpus <- VCorpus(VectorSource(reddit$raw)) %>%
  tm_map(content_transformer(tolower)) %>%
  tm_map(content_transformer(removeWords), stopwords("english")) %>%
  tm_map(removePunctuation) %>%
  tm_map(removeNumbers) %>%
  tm_map(content_transformer(lemmatize_strings)) %>%
  tm_map(stripWhitespace) %>%
  tm_map(PlainTextDocument)

# Cleaned text back into the table.
reddit$clean_text <- str_squish(sapply(corpus, function(d) as.character(d$content)))

# Extra filler words that survive but carry no meaning. Edit as needed.
extra_stop <- c("get","like","just","one","can","will","dont","im","thing","really",
                "donut","beep","boop","isk","rope","autopost","karma","lol","civil",
                "perform","action","uve","ure","stuff","happen","real",
                "subredditmessagecompose","moderator","cable","slack",
                "nautical","corrosionresistant","deck")
reddit <- reddit %>%
  mutate(clean_text = str_replace_all(clean_text,
                                      paste0("\\b(", paste(extra_stop, collapse="|"), ")\\b"), " "),
         clean_text = str_squish(clean_text)) %>%
  filter(clean_text != "")

# Build the two classes
# AFINN scores each word -5..+5. Sum per comment -> positive / negative / neutral.
afinn <- get_sentiments("afinn")

scores <- reddit %>%
  select(doc_id, clean_text) %>%
  unnest_tokens(word, clean_text) %>%
  inner_join(afinn, by = "word") %>%
  group_by(doc_id) %>%
  summarise(sent_score = sum(value), .groups = "drop")

reddit <- reddit %>%
  left_join(scores, by = "doc_id") %>%
  mutate(sent_score = ifelse(is.na(sent_score), 0, sent_score),
         class = case_when(sent_score > 0 ~ "positive",
                           sent_score < 0 ~ "negative",
                           TRUE ~ "neutral"))

cat("Class balance:\n"); print(table(reddit$class))

# For the two-class comparison we use pos vs neg (neutral set aside).
reddit2 <- reddit %>% filter(class %in% c("positive","negative"))

# Tidy unigrams (one word per row), tagged with class + platform.
tokens_uni <- reddit2 %>%
  select(doc_id, class, platform_category, clean_text) %>%
  unnest_tokens(word, clean_text) %>%
  filter(!word %in% stop_words$word, str_length(word) > 2)

# Tidy bigrams (word pairs), stopword-filtered on both sides.
tokens_bi <- reddit2 %>%
  select(doc_id, class, platform_category, clean_text) %>%
  unnest_tokens(bigram, clean_text, token = "ngrams", n = 2) %>%
  filter(!is.na(bigram)) %>%
  separate(bigram, c("word1","word2"), sep = " ") %>%
  filter(!word1 %in% stop_words$word, !word2 %in% stop_words$word,
         str_length(word1) > 2, str_length(word2) > 2) %>%
  unite(bigram, word1, word2, sep = " ")



# 2. Exploratory Analysis

# Top 10 words per class (bar plot) 
top_words <- tokens_uni %>%
  count(class, word, sort = TRUE) %>%
  group_by(class) %>%
  slice_max(n, n = 10) %>%
  ungroup()

ggplot(top_words, aes(reorder_within(word, n, class), n, fill = class)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~class, scales = "free_y") +
  scale_x_reordered() +
  coord_flip() +
  labs(title = "Top 10 words per class", x = NULL, y = "Count") +
  theme_minimal()

# Commonality cloud (words shared by both classes) 
# Counts per class -> wide table; comparison.cloud needs a word x class matrix.
word_mat <- tokens_uni %>%
  count(class, word) %>%
  acast(word ~ class, value.var = "n", fill = 0)

commonality.cloud(word_mat, max.words = 100, random.order = FALSE)

# Comparison cloud (words distinct to each class), unigrams
comparison.cloud(word_mat, max.words = 100, random.order = FALSE,
                 title.size = 1.2)

# Comparison cloud, bigrams 
bi_mat <- tokens_bi %>%
  count(class, bigram) %>%
  acast(bigram ~ class, value.var = "n", fill = 0)

comparison.cloud(bi_mat, max.words = 60, random.order = FALSE, title.size = 1.2)



# 3. Structural & Sentiment Analysis

# Word co-occurrence network (from bigrams)
# Count word pairs; keep only the strongest; draw as a graph.
bigram_counts <- tokens_bi %>%
  separate(bigram, c("word1","word2"), sep = " ") %>%
  count(word1, word2, sort = TRUE) %>%
  rename(weight = n)

# Lower threshold = more connections show; cap at top 60 pairs = stays readable.
threshold <- 8
network <- bigram_counts %>%
  filter(weight > threshold) %>%
  slice_max(weight, n = 60) %>%
  graph_from_data_frame(directed = FALSE)

deg <- degree(network)   # how connected each word is

plot(network,
     layout             = layout_with_fr(network),
     vertex.size        = 4,               # fixed small size (no more blobs)
     vertex.color       = "orange",
     vertex.label.color = "black",
     vertex.label.cex   = 0.7,             # smaller text
     vertex.label.dist  = 0,               # label sits on the node
     edge.width         = E(network)$weight / 8,
     edge.color         = "gray70",
     main = "Word co-occurrence network",
     sub  = paste0("Top 60 pairs, threshold > ", threshold))

# Sentiment comparison: both classes on one graph (NRC emotions)
# syuzhet scores the raw text against NRC's 8 emotions + 2 polarities.
emo_pos <- get_nrc_sentiment(reddit2$body[reddit2$class == "positive"])
emo_neg <- get_nrc_sentiment(reddit2$body[reddit2$class == "negative"])

# Average each emotion within each class, then combine for plotting.
emo_df <- bind_rows(
  data.frame(class = "positive", emotion = names(emo_pos), score = colMeans(emo_pos)),
  data.frame(class = "negative", emotion = names(emo_neg), score = colMeans(emo_neg))
)

ggplot(emo_df, aes(emotion, score, fill = class)) +
  geom_col(position = "dodge") +
  coord_flip() +
  labs(title = "NRC sentiment: positive vs negative class",
       x = NULL, y = "Average score per comment") +
  theme_minimal()


# 4. Advanced Modeling

# LDA topic modeling (3–5 topics per class)
# Helper: take one class, build a DTM, fit LDA, return top terms per topic.
run_lda <- function(data, k = 4) {
  dtm <- data %>%
    count(doc_id, word) %>%
    cast_dtm(doc_id, word, n)
  dtm <- removeSparseTerms(dtm, 0.99)         
  dtm <- dtm[slam::row_sums(dtm) > 0, ]       
  LDA(dtm, k = k, method = "Gibbs",
      control = list(burnin = 500, iter = 800, keep = 50, alpha = 0.5))
}                                              

# Run separately for each class so topics are class-specific.
lda_positive <- run_lda(tokens_uni %>% filter(class == "positive"), k = 4)
lda_negative <- run_lda(tokens_uni %>% filter(class == "negative"), k = 4)

cat("\n--- LDA topics: POSITIVE class ---\n"); print(terms(lda_positive, 10))
cat("\n--- LDA topics: NEGATIVE class ---\n"); print(terms(lda_negative, 10))

lda_negative %>%
  tidy(matrix = "beta") %>%
  group_by(topic) %>%
  slice_max(beta, n = 8) %>%
  ungroup() %>%
  ggplot(aes(reorder_within(term, beta, topic), beta, fill = factor(topic))) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~topic, scales = "free_y") +
  scale_x_reordered() +
  coord_flip() +
  labs(title = "LDA topics (negative class)", x = NULL, y = "Word weight (beta)") +
  theme_minimal()


# LDA on bigrams (2-gram topics, required by the brief)
# Same idea as above, but each "term" is a word pair instead of a single word.
run_lda_bigram <- function(data, k = 4) {
  dtm <- data %>%
    count(doc_id, bigram) %>%          # count word-pairs per comment
    cast_dtm(doc_id, bigram, n)
  dtm <- removeSparseTerms(dtm, 0.995) # bigrams are rarer, so keep more
  dtm <- dtm[slam::row_sums(dtm) > 0, ]
  m <- LDA(dtm, k = k, method = "Gibbs",
           control = list(burnin = 500, iter = 800, keep = 50, alpha = 0.5))
  as.matrix(terms(m, 10))
}

lda_positive_bi <- run_lda_bigram(tokens_bi %>% filter(class == "positive"), k = 4)
lda_negative_bi <- run_lda_bigram(tokens_bi %>% filter(class == "negative"), k = 4)

cat("\n--- LDA bigram topics: POSITIVE class ---\n"); print(lda_positive_bi)
cat("\n--- LDA bigram topics: NEGATIVE class ---\n"); print(lda_negative_bi)


# GloVe embeddings (semantic neighbours of key terms)
# Learn word vectors from the whole cleaned corpus, then find nearest words.
tokens_list <- space_tokenizer(reddit2$clean_text)
it <- itoken(tokens_list, progressbar = FALSE)
vocab <- create_vocabulary(it) %>% prune_vocabulary(term_count_min = 5)
vectorizer <- vocab_vectorizer(vocab)

# Term co-occurrence matrix within a 5-word window, then fit GloVe.
tcm <- create_tcm(it, vectorizer, skip_grams_window = 5)
glove <- GlobalVectors$new(rank = 50, x_max = 10)
wv_main <- glove$fit_transform(tcm, n_iter = 20)
word_vectors <- wv_main + t(glove$components)   # final vectors

# Find nearest neighbours of a target word by cosine similarity.
neighbours <- function(word, n = 10) {
  if (!word %in% rownames(word_vectors)) return(paste(word, "not in vocab"))
  target <- word_vectors[word, , drop = FALSE]
  sims <- sim2(word_vectors, target, method = "cosine", norm = "l2")[,1]
  head(sort(sims, decreasing = TRUE), n + 1)[-1]   # drop the word itself
}

cat("\nNeighbours of 'trust':\n");  print(neighbours("trust"))
cat("\nNeighbours of 'bot':\n");    print(neighbours("bot"))
cat("\nNeighbours of 'host':\n");   print(neighbours("host"))

# GloVe neighbour bar chart 
# Shows the nearest words to a key term, by similarity score.
plot_neighbours <- function(word, n = 10) {
  nb <- neighbours(word, n)
  data.frame(neighbour = names(nb), similarity = as.numeric(nb)) %>%
    ggplot(aes(reorder(neighbour, similarity), similarity)) +
    geom_col(fill = "steelblue") +
    coord_flip() +
    labs(title = paste0("Words most similar to '", word, "'"),
         x = NULL, y = "Cosine similarity") +
    theme_minimal()
}

plot_neighbours("bot")
plot_neighbours("trust")
plot_neighbours("host")

# GloVe 2D word map (PCA)
# Project the 50-number vectors down to 2D so similar words sit close together.
key_words <- c("bot","human","host","guest","trust","support","automate",
               "review","customer","contact","turo","airbnb")
key_words <- key_words[key_words %in% rownames(word_vectors)]

coords <- prcomp(word_vectors[key_words, ])$x[, 1:2] %>%
  as.data.frame()
coords$word <- rownames(coords)

ggplot(coords, aes(PC1, PC2, label = word)) +
  geom_point(color = "steelblue", size = 3) +
  geom_text(vjust = -0.8, size = 4) +
  labs(title = "GloVe word map (key terms)", x = "Dimension 1", y = "Dimension 2") +
  theme_minimal()


# 5. Save figures and tables, then add the Trustpilot comparison
suppressWarnings(suppressMessages({ library(scales); library(RColorBrewer); library(ggraph) }))
grDevices::graphics.off()
options(device = function(...) grDevices::png(tempfile(fileext = ".png")))
dir.create("figures", showWarnings = FALSE)
dir.create("outputs", showWarnings = FALSE)

# exploratory figures
ggsave("figures/fig_01_top_words.png",
  ggplot(top_words, aes(reorder_within(word, n, class), n, fill = class)) +
    geom_col(show.legend = FALSE) + facet_wrap(~class, scales = "free_y") +
    scale_x_reordered() + coord_flip() +
    scale_fill_manual(values = c(positive = "#41ab5d", negative = "#e6550d")) +
    labs(title = "Top 10 words per class", x = NULL, y = "Word count") + theme_minimal(),
  width = 9, height = 4.6, dpi = 150)

png("figures/fig_02_commonality_cloud.png", width = 1400, height = 1100, res = 200)
commonality.cloud(word_mat, max.words = 120, random.order = FALSE, colors = brewer.pal(6, "Dark2"))
dev.off()
png("figures/fig_03_comparison_cloud.png", width = 1500, height = 1100, res = 200)
comparison.cloud(word_mat, max.words = 120, random.order = FALSE, title.size = 1.4,
                 colors = c("#e6550d", "#41ab5d"))
dev.off()
png("figures/fig_04_comparison_cloud_bigram.png", width = 1500, height = 1100, res = 200)
comparison.cloud(bi_mat, max.words = 70, random.order = FALSE, title.size = 1.4,
                 colors = c("#e6550d", "#41ab5d"))
dev.off()

ggsave("figures/fig_05_sentiment_nrc.png",
  ggplot(emo_df, aes(reorder(emotion, score), score, fill = class)) +
    geom_col(position = "dodge") + coord_flip() +
    scale_fill_manual(values = c(positive = "#41ab5d", negative = "#e6550d")) +
    labs(title = "NRC sentiment by class", x = NULL,
         y = "Average score per comment", fill = "Class") + theme_minimal(),
  width = 8, height = 4.8, dpi = 150)

# co-occurrence network
V(network)$deg <- degree(network)
set.seed(42)
ggsave("figures/fig_06_network.png",
  ggraph(network, layout = "fr") +
    geom_edge_link(aes(width = weight), colour = "grey75", alpha = 0.6, show.legend = FALSE) +
    geom_node_point(aes(size = deg), colour = "#2c7fb8", show.legend = FALSE) +
    geom_node_text(aes(label = name), repel = TRUE, size = 3.2, max.overlaps = 40,
                   segment.colour = "grey85") +
    scale_edge_width(range = c(0.3, 2)) + scale_size(range = c(2, 7)) +
    labs(title = "Word co-occurrence network (Reddit bigrams)") + theme_void(base_size = 12),
  width = 9, height = 6.5, dpi = 150)

# LDA topic terms -> CSV
write.csv(as.data.frame(as.matrix(terms(lda_negative, 10))), "outputs/lda_negative_unigram.csv", row.names = FALSE)
write.csv(as.data.frame(as.matrix(terms(lda_positive, 10))), "outputs/lda_positive_unigram.csv", row.names = FALSE)
write.csv(as.data.frame(lda_negative_bi), "outputs/lda_negative_bigram.csv",  row.names = FALSE)
write.csv(as.data.frame(lda_positive_bi), "outputs/lda_positive_bigram.csv",  row.names = FALSE)

# LDA beta chart and GloVe word map as report figures.
ggsave("figures/fig_07_lda_negative.png",
  lda_negative %>%
    tidy(matrix = "beta") %>%
    group_by(topic) %>%
    slice_max(beta, n = 8) %>%
    ungroup() %>%
    ggplot(aes(reorder_within(term, beta, topic), beta, fill = factor(topic))) +
    geom_col(show.legend = FALSE) +
    facet_wrap(~topic, scales = "free_y") +
    scale_x_reordered() +
    coord_flip() +
    labs(title = "LDA topics (negative class)", x = NULL, y = "Word weight (beta)") +
    theme_minimal(),
  width = 9, height = 6, dpi = 150)

ggsave("figures/fig_13_glove_word_map.png",
  ggplot(coords, aes(PC1, PC2, label = word)) +
    geom_point(color = "steelblue", size = 3) +
    geom_text(vjust = -0.8, size = 4) +
    labs(title = "GloVe word map (key terms)", x = "Dimension 1", y = "Dimension 2") +
    theme_minimal(),
  width = 7.5, height = 5.5, dpi = 150)

# GloVe neighbours -> CSV
keys <- c("trust", "bot", "human", "host", "automate")
nb_df <- data.frame(term = keys, neighbours = vapply(keys, function(k) {
  v <- neighbours(k, 8)
  if (is.character(v)) "(not in vocabulary)" else paste(names(v), collapse = ", ")
}, character(1)))
write.csv(nb_df, "outputs/embeddings_neighbours.csv", row.names = FALSE)
print(nb_df)

# 6. Validation against Trustpilot star ratings
clean_light <- function(x) {
  x <- tolower(ifelse(is.na(x), "", as.character(x)))
  x <- gsub("http\\S+|www\\.\\S+", " ", x); x <- gsub("&amp;", "and", x)
  x <- gsub("[^a-z ]", " ", x); str_squish(x)
}
tp <- read_csv("data/trustpilot_flagged.csv", show_col_types = FALSE) %>%
  mutate(doc_id = row_number(),
         text = str_squish(paste(coalesce(title, ""), coalesce(body, ""))),
         rating = suppressWarnings(as.numeric(rating)),
         ai_related = as.logical(ai_related)) %>%
  filter(text != "", !is.na(rating))
tp$clean <- clean_light(tp$text)
tp_sc <- tp %>% select(doc_id, clean) %>% unnest_tokens(word, clean) %>%
  inner_join(afinn, by = "word") %>%
  group_by(doc_id) %>% summarise(sent = sum(value), .groups = "drop")
tp <- tp %>% left_join(tp_sc, by = "doc_id") %>%
  mutate(sent = ifelse(is.na(sent), 0, sent),
         lex_class  = case_when(sent > 0 ~ "positive", sent < 0 ~ "negative", TRUE ~ "neutral"),
         star_class = case_when(rating >= 4 ~ "positive", rating <= 2 ~ "negative", TRUE ~ "neutral"))

val <- tp %>% filter(lex_class != "neutral", star_class != "neutral")
conf <- val %>% count(star_class, lex_class) %>%
  pivot_wider(names_from = lex_class, values_from = n, values_fill = 0)
agreement <- mean(val$star_class == val$lex_class)
kt <- table(val$star_class, val$lex_class)
po <- sum(diag(kt)) / sum(kt); pe <- sum(rowSums(kt) * colSums(kt)) / sum(kt)^2
kappa <- (po - pe) / (1 - pe)
cat(sprintf("\nValidation: %.1f%% agreement, kappa %.2f (n=%d)\n", 100*agreement, kappa, nrow(val)))
write.csv(conf, "outputs/validity_confusion.csv", row.names = FALSE)

ggsave("figures/fig_08_validity.png",
  val %>% count(star_class, lex_class) %>% group_by(star_class) %>%
    mutate(prop = n / sum(n)) %>% ungroup() %>%
    ggplot(aes(lex_class, star_class, fill = prop)) +
    geom_tile(colour = "white") +
    geom_text(aes(label = sprintf("%d\n%.0f%%", n, 100*prop)), size = 4.2) +
    scale_fill_gradient(low = "#f2f7fb", high = "#2c7fb8", labels = percent) +
    labs(title = "Inferred class vs. real star rating (Trustpilot)",
         subtitle = sprintf("%.0f%% agreement, kappa = %.2f", 100*agreement, kappa),
         x = "Sentiment-inferred class (the Reddit method)",
         y = "Star-based class (ground truth)", fill = "Row share") + theme_minimal(),
  width = 7, height = 4.6, dpi = 150)

# 7. Shared themes and the AI-role gradient
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
                          "lonely","human.?like","conversation","character","empath"))
theme_labels <- c(automation_vs_human="Automation vs. human", trust_safety="Trust & safety",
                  pricing_fees="Pricing & fees", accuracy_quality="Accuracy & quality",
                  support_resolution="Support & resolution", anthro_companion="Anthropomorphism")
tag_themes <- function(text) {
  low <- tolower(ifelse(is.na(text), "", as.character(text)))
  as.data.frame(lapply(THEMES, function(p)
    str_detect(low, regex(paste(p, collapse = "|"), ignore_case = TRUE))))
}

r_th <- bind_cols(reddit2 %>% transmute(source = "Reddit", class), tag_themes(reddit2$body))
t_th <- bind_cols(tp %>% filter(star_class %in% c("positive","negative")) %>%
                    transmute(source = "Trustpilot", class = star_class),
                  tag_themes(tp$text[tp$star_class %in% c("positive","negative")]))
theme_long <- bind_rows(r_th, t_th) %>%
  pivot_longer(all_of(names(THEMES)), names_to = "theme", values_to = "hit") %>%
  group_by(source, class, theme) %>%
  summarise(prevalence = mean(hit), .groups = "drop") %>%
  mutate(theme_label = theme_labels[theme])
write.csv(theme_long, "outputs/theme_prevalence.csv", row.names = FALSE)

ggsave("figures/fig_09_themes.png",
  ggplot(theme_long, aes(reorder(theme_label, prevalence), prevalence, fill = class)) +
    geom_col(position = "dodge") + coord_flip() + facet_wrap(~source) +
    scale_y_continuous(labels = percent) +
    scale_fill_manual(values = c(positive = "#41ab5d", negative = "#e6550d")) +
    labs(title = "AI-acceptance themes by class and source", x = NULL,
         y = "Share mentioning theme", fill = "Class") + theme_minimal(),
  width = 9, height = 5, dpi = 150)

drivers <- theme_long %>% select(source, class, theme, theme_label, prevalence) %>%
  pivot_wider(names_from = class, values_from = prevalence) %>%
  mutate(lift = negative / positive)
drivers_wide <- drivers %>% select(theme, theme_label, source, lift) %>%
  pivot_wider(names_from = source, values_from = lift) %>%
  mutate(cross_validated = (Reddit > 1) & (Trustpilot > 1)) %>%
  arrange(desc((Reddit + Trustpilot) / 2))
write.csv(drivers_wide, "outputs/negativity_drivers_wide.csv", row.names = FALSE)

ggsave("figures/fig_10_drivers.png",
  ggplot(drivers, aes(reorder(theme_label, lift), lift, fill = source)) +
    geom_col(position = "dodge") + geom_hline(yintercept = 1, linetype = "dashed", colour = "grey30") +
    coord_flip() + scale_fill_manual(values = c(Reddit = "#756bb1", Trustpilot = "#2c7fb8")) +
    labs(title = "What drives the negative class",
         subtitle = "Lift above 1 means the theme is more common in negative text",
         x = NULL, y = "Negative / positive prevalence (lift)", fill = "Source") + theme_minimal(),
  width = 9, height = 5, dpi = 150)

reddit_grad <- reddit2 %>% group_by(platform_category) %>%
  summarise(n = n(), pct_positive = mean(class == "positive"), .groups = "drop")
write.csv(reddit_grad, "outputs/role_gradient.csv", row.names = FALSE)

# Robustness check: the keyword scrape also returns general platform talk
# (mainly via the broad 'app' query), so re-measure the gradient using only
# comments that explicitly mention AI, automation, bots or a named AI product.
ai_terms <- paste0(
  "(?i)\\bai\\b|artificial intelligence|automat|\\bbots?\\b|chatbot|chat bot|",
  "algorithm|machine learning|gpt|\\bllms?\\b|language model|",
  "chatgpt|claude|gemini|\\bbard\\b|replika|copilot|perplexity|character\\.?ai|openai|anthropic")
reddit_grad_ai <- reddit2 %>%
  filter(str_detect(body, ai_terms)) %>%
  group_by(platform_category) %>%
  summarise(n = n(), pct_positive = mean(class == "positive"), .groups = "drop")
write.csv(reddit_grad_ai, "outputs/role_gradient_ai_only.csv", row.names = FALSE)
cat(sprintf("Role gradient (explicit AI mentions only): %s\n",
            paste(sprintf("%s %.1f%% (n=%d)", reddit_grad_ai$platform_category,
                          100 * reddit_grad_ai$pct_positive, reddit_grad_ai$n), collapse = " | ")))

ggsave("figures/fig_12_role_gradient_ai_only.png",
  reddit_grad_ai %>%
    mutate(label = recode(platform_category, ai_service = "AI-native",
                          rental = "Rental", customer_service = "Customer service"),
           label = paste0(label, "\n(n = ", n, ")"),
           label = reorder(label, -pct_positive)) %>%
    ggplot(aes(label, 100 * pct_positive)) +
    geom_col(width = 0.6, fill = "#2c7fb8") +
    geom_text(aes(label = sprintf("%.1f%%", 100 * pct_positive)), vjust = -0.4, size = 4.5) +
    ylim(0, 75) +
    labs(title = "Positive acceptance by AI role",
         subtitle = "Reddit comments that explicitly mention AI or automation only",
         x = NULL, y = "Positive share (%)") + theme_minimal(),
  width = 6.5, height = 4.4, dpi = 150)

penalty <- tp %>% filter(!is.na(ai_related)) %>% group_by(ai_related) %>%
  summarise(n = n(), mean_rating = mean(rating), .groups = "drop")
ai_star  <- penalty$mean_rating[penalty$ai_related == TRUE]
non_star <- penalty$mean_rating[penalty$ai_related == FALSE]
write.csv(penalty, "outputs/ai_penalty.csv", row.names = FALSE)
cat(sprintf("AI penalty: %.2f vs %.2f stars\n", ai_star, non_star))

ggsave("figures/fig_11_ai_penalty.png",
  penalty %>% mutate(label = ifelse(ai_related, "Mentions AI / automation", "No AI mention")) %>%
    ggplot(aes(reorder(label, mean_rating), mean_rating, fill = ai_related)) +
    geom_col(width = 0.6, show.legend = FALSE) +
    geom_text(aes(label = sprintf("%.2f", mean_rating)), vjust = -0.3, size = 4.5) +
    scale_fill_manual(values = c(`TRUE` = "#e6550d", `FALSE` = "#41ab5d")) + ylim(0, 5) +
    labs(title = "The AI / automation penalty (Trustpilot)", x = NULL,
         y = "Mean star rating (1-5)") + theme_minimal(),
  width = 6.5, height = 4.4, dpi = 150)

# 8. Strategic recommendations and headline metrics
recommendations <- tibble::tribble(
  ~priority, ~recommendation,                       ~evidence,
  1, "Keep a human one click away",                 "Automation and 'no human' is the strongest marker of negative reviews on Trustpilot (8x). On Reddit, where many users are hosts, automation is discussed positively, so the penalty shows up most on the customer side.",
  2, "Disclose the AI and admit its limits",        "Accuracy and 'doesn't work' complaints separate the classes in both sources (about 2x on Reddit, 6.6x on Trustpilot).",
  3, "Optimise for first-contact resolution",       "Slow or unresolved support is a strong negative marker on Trustpilot (1.8x) and a recurring theme in the Reddit support topics.",
  4, "Match the persona to the role",               "Anthropomorphism is welcomed when AI IS the product but reads as cold in a transaction; Reddit is most positive for AI-native services, and the Trustpilot AI penalty is a rental phenomenon.",
  5, "Show all-in price and refund rules up front", "Pricing and fees dominate negative rental reviews (5x on Trustpilot); a rental-specific, not AI-specific, frustration.")
write.csv(recommendations, "outputs/strategic_recommendations.csv", row.names = FALSE)

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
  "n_cross_drivers", as.character(sum(drivers_wide$cross_validated, na.rm = TRUE)))
write.csv(metrics, "outputs/metrics.csv", row.names = FALSE)

cat("\nDone. figures/ and outputs/ written.\n")
