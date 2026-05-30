setwd("~/Desktop/Online Content Analysis/Final Project")

all_comments      <- read.csv("reddit_all.csv",      stringsAsFactors = FALSE)
comments_positive <- read.csv("reddit_positive.csv", stringsAsFactors = FALSE)
comments_negative <- read.csv("reddit_negative.csv", stringsAsFactors = FALSE)

all_comments
comments_positive
comments_negative
