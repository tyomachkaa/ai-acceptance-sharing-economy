# =============================================================================
# 06_ai_acceptance.R
# Flags Trustpilot reviews that describe an AI / automation experience and
# tags every review with a platform category, so the project can study
# "AI acceptance across service platforms".
#
# Forward-compatible: when you scrape MORE platforms into trustpilot_raw/ and
# re-run 02_merge_trustpilot.R, just re-run this script -- new platforms are
# auto-categorised (add them to the lookup below if unknown).
#
# Input : data/trustpilot_reviews.csv
# Output: data/trustpilot_flagged.csv   (all reviews + platform_category + ai_related + ai_signals)
#         data/ai_experience.csv        (the AI/automation subset only)
# =============================================================================

suppressWarnings(suppressMessages(library(dplyr)))

tp <- read.csv("data/trustpilot_reviews.csv", stringsAsFactors = FALSE)
norm <- function(p) sub("\\.com$", "", tolower(gsub("\\s+", "", p)))
tp$plat <- norm(tp$platform)

# ---- platform category lookup -------------------------------------------------
# Extend this as you add platforms. Categories let us compare AI acceptance
# where AI is peripheral (rentals) vs where AI is the product (ai_service)
# vs where AI runs support (fintech_ai).
category <- c(
  # P2P rental / sharing economy (AI is a peripheral automation layer)
  turo="rental", fatllama="rental", rvshare="rental", outdoorsy="rental",
  getaround="rental", kitsplit="rental", lensrentals="rental", sharegrid="rental",
  # AI-native services (AI IS the product)
  openai="ai_service", chatgpt="ai_service", character="ai_service",
  characterai="ai_service", replika="ai_service", perplexity="ai_service",
  jasper="ai_service", copyai="ai_service", poe="ai_service", pi="ai_service",
  # automation / AI-in-support services
  klarna="fintech_ai", revolut="fintech_ai", cleo="fintech_ai", monzo="fintech_ai"
)
tp$platform_category <- unname(ifelse(tp$plat %in% names(category),
                                      category[tp$plat], "other"))

# ---- AI / automation acceptance signal ---------------------------------------
txt <- tolower(paste(ifelse(is.na(tp$title), "", tp$title),
                     ifelse(is.na(tp$body),  "", tp$body)))
pat <- c(
  ai        = "\\b(a\\.?i\\.?|artificial intelligence|chatgpt|gpt|llm|machine learning)\\b",
  bot       = "\\b(chat\\s?bot|chatbots?|bots?)\\b",
  algorithm = "\\b(algorithm|algorithmic|automated (decision|verification|screening|system|process)|ai (verification|screening|moderation|decision))\\b",
  automated = "\\b(automat(ed|ic|ion)|auto[- ]?(reply|response|message)|canned response)\\b",
  no_human  = "(no (human|person|one)|can'?t (reach|speak|talk).{0,20}(human|person|someone)|speak to (a |an )?(human|person|real)|actual (human|person)|real (human|person))",
  pricing   = "\\b(dynamic pricing|smart pricing|surge pricing)\\b"
)
hit <- sapply(pat, function(p) grepl(p, txt, perl = TRUE))
tp$ai_signals  <- apply(hit, 1, function(r) paste(names(pat)[r], collapse = ";"))
tp$ai_related  <- rowSums(hit) > 0
tp$plat <- NULL

# ---- write --------------------------------------------------------------------
write.csv(tp, "data/trustpilot_flagged.csv", row.names = FALSE)
ai <- tp[tp$ai_related, ]
write.csv(ai, "data/ai_experience.csv", row.names = FALSE)

# ---- report -------------------------------------------------------------------
cat(sprintf("Total reviews: %d | AI/automation-related: %d (%.1f%%)\n",
            nrow(tp), nrow(ai), 100*mean(tp$ai_related)))
cat("\nBy platform category (all reviews):\n")
print(tp |> count(platform_category, sort = TRUE))
cat("\nAI-related reviews by category:\n")
print(ai |> count(platform_category, sort = TRUE))
cat(sprintf("\nMean star: AI-related %.2f vs non-AI %.2f\n",
            mean(ai$rating, na.rm = TRUE),
            mean(tp$rating[!tp$ai_related], na.rm = TRUE)))
cat("\nWrote data/trustpilot_flagged.csv and data/ai_experience.csv\n")
