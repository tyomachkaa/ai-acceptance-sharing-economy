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
  dtm <- removeSparseTerms(dtm, 0.99)         # drop ultra-rare terms
  dtm <- dtm[slam::row_sums(dtm) > 0, ]       # drop now-empty comments
  m <- LDA(dtm, k = k, method = "Gibbs",
           control = list(burnin = 500, iter = 800, keep = 50, alpha = 0.5))
  as.matrix(terms(m, 10))                      # top 10 words per topic
}

# Run separately for each class so topics are class-specific.
lda_positive <- run_lda(tokens_uni %>% filter(class == "positive"), k = 4)
lda_negative <- run_lda(tokens_uni %>% filter(class == "negative"), k = 4)

cat("\n--- LDA topics: POSITIVE class ---\n"); print(lda_positive)
cat("\n--- LDA topics: NEGATIVE class ---\n"); print(lda_negative)

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
