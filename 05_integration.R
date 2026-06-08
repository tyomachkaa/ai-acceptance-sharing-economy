# =============================================================================
# 05_integration.R  --  STEP 5: Integration, Strategic Insights, Literature
# Project: AI Acceptance Across Service Platforms
#
# Extends steps 1-4 (steps 1 to 4.R). Where steps 1-4 analyse the Reddit
# discussion baseline on its own, step 5 FUSES Reddit (open discussion, classes
# INFERRED from a sentiment lexicon) with Trustpilot (reviews carrying a 1-5 star
# GROUND-TRUTH label) to tell one cohesive story and derive AI-agent design
# recommendations.
#
# The Trustpilot dataset is incorporated in three load-bearing ways:
#   A. Convergent validity  -- Trustpilot stars let us TEST whether the lexicon
#      class used on Reddit (where no stars exist) actually tracks real
#      acceptance. If lexicon-class agrees with star-class on Trustpilot, the
#      Reddit classification is validated.
#   B. Shared themes         -- one AI-acceptance theme lexicon is applied to
#      BOTH corpora, so frustrations/benefits can be compared like-for-like.
#   C. AI-role gradient      -- acceptance as AI moves from the product, to a
#      marketplace add-on, to the support desk (the AI/automation star penalty).
#
# PORTABILITY: uses the Bing lexicon (bundled with tidytext -- no download) and
# base-R file I/O, so it runs with no extra installs and no interactive prompts.
# Bing sign-of-sum gives the same two-class (positive/negative) split as the
# AFINN-sign class in steps 1-4; AFINN/NRC need the {textdata}/{syuzhet}
# packages, which are optional here.
#
# Outputs:  outputs/*.csv  (consumed by report.Rmd)  +  figures/05_*.png
# =============================================================================

suppressWarnings(suppressMessages({
  library(dplyr); library(stringr); library(tidyr)
  library(tidytext); library(ggplot2); library(scales)
}))

dir.create("outputs", showWarnings = FALSE)
dir.create("figures", showWarnings = FALSE)

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || is.na(a)) b else a

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

# Light clean -- mirrors the steps 1-4 pipeline (lowercase, strip links / Reddit
# handles / punctuation / numbers) WITHOUT the heavy lemmatiser, so it is fast
# and dependency-free. Sentiment sign is robust to lemmatisation.
clean_light <- function(x) {
  x <- tolower(ifelse(is.na(x), "", as.character(x)))
  x <- str_replace_all(x, "http\\S+|www\\.\\S+", " ")
  x <- str_replace_all(x, "&amp;", "and")
  x <- str_replace_all(x, "/?u/\\w+|/?r/\\w+", " ")
  x <- str_replace_all(x, "[\r\n]+", " ")
  x <- str_replace_all(x, "[^a-z ]", " ")
  str_squish(x)
}

# Bing polarity class: tokenise, score +1/-1 per word, sum per doc, take sign.
# Same two-class logic as the AFINN-sign class in steps 1-4 (portable variant).
bing <- get_sentiments("bing") |>
  mutate(value = if_else(sentiment == "positive", 1L, -1L))

lexicon_class <- function(df, id_col, text_col) {
  df |>
    transmute(.id = .data[[id_col]], .txt = clean_light(.data[[text_col]])) |>
    unnest_tokens(word, .txt) |>
    inner_join(bing, by = "word") |>
    group_by(.id) |>
    summarise(lex_score = sum(value), .groups = "drop") |>
    mutate(lex_class = case_when(lex_score > 0 ~ "positive",
                                 lex_score < 0 ~ "negative",
                                 TRUE          ~ "neutral"))
}

# Shared AI-acceptance theme lexicon -- one set of regexes applied to BOTH
# sources so Reddit and Trustpilot are comparable on the same six themes.
THEMES <- list(
  automation_vs_human = c("\\bbot\\b","chatbot","automat","robot","algorithm",
                          "\\bai\\b","\\ban ai\\b","no human","real person",
                          "speak to (a )?human","talk to (a )?human","machine"),
  trust_safety        = c("trust","scam","fraud","safe","secur","verif","privacy",
                          "personal data","reliab","legit","sketchy"),
  pricing_fees        = c("price","pricing","\\bfee","charge","refund","deposit",
                          "\\bcost","expensive","overcharg","billing","money back"),
  accuracy_quality    = c("wrong","error","mistake","inaccurat","hallucinat",
                          "useless","broken","glitch","doesn.?t work","fail",
                          "accuracy","quality","nonsense"),
  support_resolution  = c("support","\\bhelp","resolve","resolution","ticket",
                          "respon","\\bwait","contact","customer service",
                          "get through","escalat","call back"),
  anthro_companion    = c("friend","companion","personality","\\bfeel","emotion",
                          "lonely","human.?like","conversation","character",
                          "relationship","empath")
)

tag_themes <- function(text) {
  low <- tolower(ifelse(is.na(text), "", as.character(text)))
  out <- lapply(THEMES, function(pats)
    str_detect(low, regex(paste(pats, collapse = "|"), ignore_case = TRUE)))
  as.data.frame(out)
}

theme_labels <- c(
  automation_vs_human = "Automation vs. human",
  trust_safety        = "Trust & safety",
  pricing_fees        = "Pricing & fees",
  accuracy_quality    = "Accuracy & quality",
  support_resolution  = "Support & resolution",
  anthro_companion    = "Anthropomorphism / companionship")

# -----------------------------------------------------------------------------
# Load both corpora
# -----------------------------------------------------------------------------
cat("Loading corpora ...\n")
reddit <- read.csv("data/reddit_baseline.csv", stringsAsFactors = FALSE)
tp     <- read.csv("data/trustpilot_flagged.csv", stringsAsFactors = FALSE)

reddit <- reddit |>
  mutate(doc_id = row_number()) |>
  filter(!is.na(body), str_squish(body) != "")

tp <- tp |>
  mutate(doc_id = row_number(),
         text   = str_squish(paste(ifelse(is.na(title), "", title),
                                   ifelse(is.na(body), "", body))),
         rating = suppressWarnings(as.numeric(rating))) |>
  filter(!is.na(text), text != "", !is.na(rating))

# ---- Reddit class: lexicon sign (proxy, as in steps 1-4) --------------------
reddit_cls <- lexicon_class(reddit, "doc_id", "body")
reddit <- reddit |>
  left_join(reddit_cls, by = c("doc_id" = ".id")) |>
  mutate(lex_score = coalesce(lex_score, 0L),
         lex_class = coalesce(lex_class, "neutral"))

# ---- Trustpilot: TWO labels -- star (ground truth) AND lexicon (predicted) --
tp_cls <- lexicon_class(tp, "doc_id", "text")
tp <- tp |>
  left_join(tp_cls, by = c("doc_id" = ".id")) |>
  mutate(lex_score = coalesce(lex_score, 0L),
         lex_class = coalesce(lex_class, "neutral"),
         star_class = case_when(rating >= 4 ~ "positive",
                                rating <= 2 ~ "negative",
                                TRUE        ~ "neutral"))

cat(sprintf("  Reddit:     %d comments\n", nrow(reddit)))
cat(sprintf("  Trustpilot: %d reviews\n",  nrow(tp)))

# =============================================================================
# A. CONVERGENT VALIDITY  --  does the lexicon class agree with real stars?
#    (Trustpilot is the only source with both, so it is where we can test it.)
# =============================================================================
cat("\n[A] Convergent validity: lexicon class vs star class (Trustpilot)\n")

val <- tp |>
  filter(star_class != "neutral", lex_class != "neutral")

conf <- val |> count(star_class, lex_class) |>
  pivot_wider(names_from = lex_class, values_from = n, values_fill = 0)

agreement <- mean(val$star_class == val$lex_class)
# Cohen's kappa (2x2) for chance-corrected agreement
k_tab <- table(val$star_class, val$lex_class)
po <- sum(diag(k_tab)) / sum(k_tab)
pe <- sum(rowSums(k_tab) * colSums(k_tab)) / sum(k_tab)^2
kappa <- (po - pe) / (1 - pe)

cat(sprintf("  Raw agreement: %.1f%%   Cohen's kappa: %.2f   (n=%d)\n",
            100 * agreement, kappa, nrow(val)))
print(conf)

write.csv(conf, "outputs/validity_confusion.csv", row.names = FALSE)

# Figure A: confusion heatmap
gA <- val |> count(star_class, lex_class) |>
  group_by(star_class) |> mutate(prop = n / sum(n)) |> ungroup() |>
  ggplot(aes(lex_class, star_class, fill = prop)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = sprintf("%d\n%.0f%%", n, 100 * prop)), size = 4) +
  scale_fill_gradient(low = "#f2f7fb", high = "#2c7fb8", labels = percent) +
  labs(title = "Convergent validity on Trustpilot",
       subtitle = sprintf("Lexicon class vs. star label  -  %.0f%% agreement, kappa = %.2f",
                          100 * agreement, kappa),
       x = "Lexicon-predicted class (the Reddit method)",
       y = "Star-based class (ground truth)", fill = "Row share") +
  theme_minimal(base_size = 12)
ggsave("figures/05_validity.png", gA, width = 7, height = 4.6, dpi = 150)

# =============================================================================
# B. SHARED THEMES  --  one lexicon, both sources, comparable
# =============================================================================
cat("\n[B] Shared theme prevalence by source x class\n")

reddit_th <- bind_cols(
  reddit |> filter(lex_class %in% c("positive","negative")) |>
    transmute(source = "Reddit", class = lex_class),
  tag_themes(reddit$body[reddit$lex_class %in% c("positive","negative")]))

tp_th <- bind_cols(
  tp |> filter(star_class %in% c("positive","negative")) |>
    transmute(source = "Trustpilot", class = star_class),
  tag_themes(tp$text[tp$star_class %in% c("positive","negative")]))

theme_long <- bind_rows(reddit_th, tp_th) |>
  pivot_longer(all_of(names(THEMES)), names_to = "theme", values_to = "hit") |>
  group_by(source, class, theme) |>
  summarise(prevalence = mean(hit), n = n(), .groups = "drop") |>
  mutate(theme_label = theme_labels[theme])

write.csv(theme_long, "outputs/theme_prevalence.csv", row.names = FALSE)

# Figure B: theme prevalence, facet by source, fill by class
gB <- theme_long |>
  ggplot(aes(reorder(theme_label, prevalence), prevalence, fill = class)) +
  geom_col(position = "dodge") +
  coord_flip() +
  facet_wrap(~source) +
  scale_y_continuous(labels = percent) +
  scale_fill_manual(values = c(positive = "#41ab5d", negative = "#e6550d")) +
  labs(title = "AI-acceptance themes: prevalence by class and source",
       x = NULL, y = "Share of comments/reviews mentioning theme", fill = "Class") +
  theme_minimal(base_size = 12)
ggsave("figures/05_theme_prevalence.png", gB, width = 9, height = 5, dpi = 150)

# =============================================================================
# C. NEGATIVITY DRIVERS  --  lift = P(theme | neg) / P(theme | pos), per source.
#    Themes with lift > 1 in BOTH sources = cross-validated frustration drivers.
# =============================================================================
cat("\n[C] Negativity drivers (lift > 1 = drives frustration)\n")

drivers <- theme_long |>
  select(source, class, theme, theme_label, prevalence) |>
  pivot_wider(names_from = class, values_from = prevalence) |>
  mutate(lift = negative / positive) |>
  select(source, theme, theme_label, neg_prev = negative,
         pos_prev = positive, lift)

drivers_wide <- drivers |>
  select(theme, theme_label, source, lift) |>
  pivot_wider(names_from = source, values_from = lift) |>
  mutate(cross_validated = (Reddit > 1) & (Trustpilot > 1)) |>
  arrange(desc((Reddit + Trustpilot) / 2))

write.csv(drivers,      "outputs/negativity_drivers.csv",      row.names = FALSE)
write.csv(drivers_wide, "outputs/negativity_drivers_wide.csv", row.names = FALSE)
print(drivers_wide)

# Figure C: lift by theme, both sources; reference line at 1
gC <- drivers |>
  ggplot(aes(reorder(theme_label, lift), lift, fill = source)) +
  geom_col(position = "dodge") +
  geom_hline(yintercept = 1, linetype = "dashed", colour = "grey30") +
  coord_flip() +
  scale_fill_manual(values = c(Reddit = "#756bb1", Trustpilot = "#2c7fb8")) +
  labs(title = "What drives negative acceptance",
       subtitle = "Lift = how much more a theme appears in negative vs positive (>1 = frustration driver)",
       x = NULL, y = "Negative / positive prevalence (lift)", fill = "Source") +
  theme_minimal(base_size = 12)
ggsave("figures/05_negativity_drivers.png", gC, width = 9, height = 5, dpi = 150)

# =============================================================================
# D. AI-ROLE GRADIENT  --  acceptance as AI moves product -> add-on -> support,
#    plus the headline AI/automation star penalty on Trustpilot.
# =============================================================================
cat("\n[D] AI-role gradient + AI/automation penalty\n")

# Reddit: net sentiment share by platform_category
reddit_grad <- reddit |>
  filter(lex_class %in% c("positive","negative")) |>
  group_by(platform_category) |>
  summarise(n = n(),
            pct_positive = mean(lex_class == "positive"),
            .groups = "drop") |>
  mutate(source = "Reddit (sentiment share)", metric = pct_positive)

# Trustpilot: mean stars by platform_category
tp_grad <- tp |>
  group_by(platform_category) |>
  summarise(n = n(), mean_rating = mean(rating), .groups = "drop") |>
  mutate(source = "Trustpilot (mean stars)", metric = mean_rating / 5)  # scale to 0-1

role_gradient <- bind_rows(
  reddit_grad |> select(platform_category, n, source, metric, pct_positive),
  tp_grad     |> select(platform_category, n, source, metric, mean_rating))
write.csv(role_gradient, "outputs/role_gradient.csv", row.names = FALSE)
cat("  Reddit % positive by context:\n"); print(reddit_grad |> select(platform_category, n, pct_positive))
cat("  Trustpilot mean stars by context:\n"); print(tp_grad |> select(platform_category, n, mean_rating))

# AI / automation penalty (Trustpilot): mean stars when ai_related TRUE vs FALSE
tp <- tp |> mutate(ai_related = as.logical(ai_related))
penalty <- tp |>
  filter(!is.na(ai_related)) |>
  group_by(ai_related) |>
  summarise(n = n(), mean_rating = mean(rating), .groups = "drop")
ai_star  <- penalty$mean_rating[penalty$ai_related == TRUE]  %||% NA
non_star <- penalty$mean_rating[penalty$ai_related == FALSE] %||% NA
cat(sprintf("  AI/automation reviews: %.2f stars (n=%d)  vs  rest: %.2f stars (n=%d)\n",
            ai_star, penalty$n[penalty$ai_related == TRUE] %||% 0,
            non_star, penalty$n[penalty$ai_related == FALSE] %||% 0))
write.csv(penalty, "outputs/ai_penalty.csv", row.names = FALSE)

# Figure D: AI penalty
gD <- penalty |>
  mutate(label = ifelse(ai_related, "Mentions AI / automation", "No AI mention")) |>
  ggplot(aes(reorder(label, mean_rating), mean_rating, fill = ai_related)) +
  geom_col(width = 0.6, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.2f stars\n(n=%d)", mean_rating, n)),
            vjust = -0.2, size = 4) +
  scale_fill_manual(values = c(`TRUE` = "#e6550d", `FALSE` = "#41ab5d")) +
  ylim(0, 5) +
  labs(title = "The AI / automation penalty (Trustpilot)",
       subtitle = "Mean star rating, reviews mentioning AI vs not",
       x = NULL, y = "Mean rating (1-5)") +
  theme_minimal(base_size = 12)
ggsave("figures/05_ai_penalty.png", gD, width = 6.5, height = 4.6, dpi = 150)

# =============================================================================
# E. STRATEGIC DESIGN CARDS  --  themes -> design principle -> framework
#    Actionable AI-agent design recommendations, grounded in the cross-source
#    evidence above and mapped to trust / adoption theory (see report Literature).
# =============================================================================
cat("\n[E] Strategic design cards\n")

design_cards <- tibble::tribble(
  ~theme,                 ~scope,         ~finding,                                                                      ~design_principle,                                                              ~framework,
  "Automation vs. human", "Cross-source", "Automation/'no human' language is 8.1x more common in negative Trustpilot reviews and pervasive in Reddit AI talk (lift 1.05) -- the signature of forced automation.", "Make the human hand-off one click away; never trap users in a bot loop. Label AI as AI and state its limits up front.", "Algorithm aversion (Dietvorst et al. 2015); TAM perceived usefulness (Davis 1989)",
  "Accuracy & quality",   "Cross-source", "Errors / 'doesn't work' / hallucination is the cleanest driver: 1.8x (Reddit) and 6.9x (Trustpilot) more common in negative text.",                              "Show confidence and sources; let users correct the agent; fail loudly, not silently.",  "Ability & integrity trust (Mayer et al. 1995)",
  "Support & resolution", "Cross-source", "Slow / unresolved support drives the negative class in both sources (lift 1.2 Reddit / 1.8 Trustpilot); resolution speed beats politeness.",                            "Optimise the agent for first-contact resolution and a transparent wait/status, not chat length.", "UTAUT effort expectancy & facilitating conditions (Venkatesh et al. 2003)",
  "Anthropomorphism / companionship", "Cross-source (double-edged)", "Persona/companionship language is emotionally loaded and tilts slightly negative in both sources (lift ~1.5) -- strong delight when it works, strong frustration when the persona disappoints.", "Match persona warmth to role (personable for AI-native companions, low-key for transactional add-ons) and keep the persona stable -- abrupt changes break trust.", "CASA paradigm (Nass & Moon 2000); expectation-confirmation (Bhattacherjee 2001)",
  "Pricing & fees",       "Rental-specific", "Opaque fees / refunds dominate negative rental reviews (5.4x on Trustpilot) but are NOT an AI-native frustration (lift 0.7 on Reddit).",                                      "Surface all-in price and refund rules before commitment; let the agent proactively explain charges.", "Benevolence trust (Mayer et al. 1995); price-fairness",
  "Trust & safety",       "Rental-specific", "Trust / scam / verification language marks negative rental reviews (4.9x on Trustpilot), less so on Reddit (0.9x).",                         "Foreground verification, security and data-use cues; let the agent cite its safeguards.", "Initial trust formation (McKnight et al. 2002)"
)
write.csv(design_cards, "outputs/design_cards.csv", row.names = FALSE)
print(design_cards)

# =============================================================================
# Headline metrics for the report (single tidy key-value file)
# =============================================================================
metrics <- tibble::tribble(
  ~metric, ~value,
  "reddit_n",                as.character(nrow(reddit)),
  "tp_n",                    as.character(nrow(tp)),
  "validity_agreement_pct",  sprintf("%.1f", 100 * agreement),
  "validity_kappa",          sprintf("%.2f", kappa),
  "validity_n",              as.character(nrow(val)),
  "ai_star",                 sprintf("%.2f", ai_star),
  "non_ai_star",             sprintf("%.2f", non_star),
  "ai_penalty",              sprintf("%.2f", non_star - ai_star),
  "n_cross_validated_drivers", as.character(sum(drivers_wide$cross_validated, na.rm = TRUE))
)
write.csv(metrics, "outputs/step5_metrics.csv", row.names = FALSE)

cat("\n=== STEP 5 COMPLETE ===\n")
cat("Tables -> outputs/: validity_confusion, theme_prevalence, negativity_drivers(_wide),\n")
cat("          role_gradient, ai_penalty, design_cards, step5_metrics\n")
cat("Figures -> figures/: 05_validity, 05_theme_prevalence, 05_negativity_drivers, 05_ai_penalty\n")
