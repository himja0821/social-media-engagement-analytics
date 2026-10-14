# =============================================================================
# 01_preprocess.R -- Load, audit and clean the social-media engagement data
# -----------------------------------------------------------------------------
# Input : data/raw/social_media_engagement.csv   (5,000 posts, 6 platforms)
# Output: data/processed/engagement_clean.csv     (tidy, analysis-ready)
#         data/processed/cleaning_log.txt          (audit trail)
#
# Run from the project root:  source("R/01_preprocess.R")
# =============================================================================

if (!exists("theme_social")) source("R/00_setup.R")

## ---- load-raw ---------------------------------------------------------------
raw_path <- file.path(DIR_RAW, "social_media_engagement.csv")
raw_data <- readr::read_csv(
  raw_path,
  show_col_types = FALSE,
  col_types = readr::cols(Timestamp = readr::col_character())
)

n_raw      <- nrow(raw_data)
n_raw_cols <- ncol(raw_data)
n_missing_raw <- sum(is.na(raw_data))

## ---- clean-timestamps -------------------------------------------------------
# Parse the text timestamp once into a real datetime. All 5,000 values share the
# "YYYY-MM-DD HH:MM:SS" layout, so parsing succeeds for every row.
ts_parsed   <- suppressWarnings(lubridate::ymd_hms(raw_data$Timestamp, quiet = TRUE))
n_bad_ts    <- sum(is.na(ts_parsed))

clean_data <- raw_data %>%
  mutate(
    Post_Timestamp = ts_parsed,
    Has_Media      = as.logical(Has_Media),
    Is_Verified    = as.logical(Is_Verified)
  )

# Internal consistency: the stored hour and weekday must agree with the datetime.
n_hour_mismatch <- sum(lubridate::hour(clean_data$Post_Timestamp) != clean_data$Hour_of_Day)
n_day_mismatch  <- sum(
  as.character(lubridate::wday(clean_data$Post_Timestamp, label = TRUE,
                               abbr = FALSE, week_start = 1)) != clean_data$Day_of_Week
)

## ---- derive-features --------------------------------------------------------
# Harmonise the platform-specific content labels (Reel / Short / Duet ... are all
# video-like) into four comparable content "formats".
format_lookup <- c(
  Video = "Video", Reel = "Video", Short = "Video", Live = "Video",
  Photo = "Image", Carousel = "Image", Story = "Image",
  Duet  = "Interactive", Stitch = "Interactive", Poll = "Interactive",
  Post  = "Text/Article", Tweet = "Text/Article", Thread = "Text/Article",
  Article = "Text/Article", Document = "Text/Article",
  `Community Post` = "Text/Article", Retweet = "Text/Article"
)

clean_data <- clean_data %>%
  mutate(
    Content_Format = unname(format_lookup[Content_Type]),
    Date           = lubridate::as_date(Post_Timestamp),
    Year           = lubridate::year(Post_Timestamp),
    Month          = lubridate::month(Post_Timestamp, label = TRUE, abbr = TRUE),
    Year_Month     = lubridate::floor_date(Post_Timestamp, "month"),
    Weekday        = lubridate::wday(Post_Timestamp, label = TRUE,
                                     abbr = FALSE, week_start = 1),
    Hour           = lubridate::hour(Post_Timestamp),
    Posting_Period = case_when(
      Hour >= 5  & Hour < 12 ~ "Morning",
      Hour >= 12 & Hour < 17 ~ "Afternoon",
      Hour >= 17 & Hour < 22 ~ "Evening",
      TRUE                   ~ "Night"
    ),
    Is_Weekend       = Weekday %in% c("Saturday", "Sunday"),
    # Volume of engagement (all interaction types)
    Total_Engagement = Likes + Comments + Shares + Saves,
    # Rate metric -- matches the supplied Engagement_Rate column (see validation)
    ER_by_Followers  = 100 * (Likes + Comments + Shares) / Follower_Count,
    ER_by_Views      = 100 * Total_Engagement / Views,
    # Data-quality flag: a post cannot be liked more often than it is seen
    Reaches_Viewers  = Views >= Total_Engagement
  )

## ---- relevel-factors --------------------------------------------------------
# Store factors with explicit levels so ordering survives the CSV round-trip.
clean_data <- clean_data %>%
  mutate(
    Platform        = factor(Platform, levels = names(PAL_PLATFORM)),
    Content_Format  = factor(Content_Format, levels = names(PAL_FORMAT)),
    Posting_Period  = factor(Posting_Period,
                             levels = c("Morning", "Afternoon", "Evening", "Night")),
    Influencer_Tier = factor(Influencer_Tier, levels = names(PAL_TIER)),
    Sentiment       = factor(Sentiment, levels = c("Negative", "Neutral", "Positive")),
    Weekday         = factor(Weekday,
                             levels = c("Monday", "Tuesday", "Wednesday", "Thursday",
                                        "Friday", "Saturday", "Sunday")),
    Has_Media       = factor(Has_Media,   levels = c(TRUE, FALSE),
                             labels = c("With media", "Without media")),
    Is_Verified     = factor(Is_Verified, levels = c(TRUE, FALSE),
                             labels = c("Verified", "Not verified"))
  )

## ---- validate-rate ----------------------------------------------------------
# Confirm how the supplied Engagement_Rate is defined, so we can trust/repurpose
# it. It equals 100 * (Likes + Comments + Shares) / Follower_Count.
rate_abs_diff <- abs(clean_data$Engagement_Rate - clean_data$ER_by_Followers)
max_rate_diff <- max(rate_abs_diff, na.rm = TRUE)

## ---- clean-summary ----------------------------------------------------------
n_dup_id      <- sum(duplicated(clean_data$Post_ID))
n_missing     <- sum(is.na(clean_data))
n_views_lt_eq <- sum(!clean_data$Reaches_Viewers)

cleaning_log <- c(
  sprintf("Raw file: %s", basename(raw_path)),
  sprintf("Raw dimensions: %d rows x %d columns", n_raw, n_raw_cols),
  sprintf("Missing values in raw file: %d", n_missing_raw),
  sprintf("Duplicate Post_IDs: %d", n_dup_id),
  sprintf("Timestamps that failed to parse: %d", n_bad_ts),
  sprintf("Timestamp vs Hour_of_Day mismatches: %d", n_hour_mismatch),
  sprintf("Timestamp vs Day_of_Week mismatches: %d", n_day_mismatch),
  sprintf("Engagement_Rate == 100*(Likes+Comments+Shares)/Follower_Count (max abs diff = %.4g)",
          max_rate_diff),
  sprintf("Content labels harmonised into %d formats: %s",
          n_distinct(clean_data$Content_Format),
          paste(levels(factor(clean_data$Content_Format)), collapse = ", ")),
  sprintf("Posts flagged Views < total engagement (retained, flagged): %d",
          n_views_lt_eq),
  sprintf("Missing values after cleaning: %d", n_missing),
  sprintf("Final dimensions: %d rows x %d columns",
          nrow(clean_data), ncol(clean_data)),
  sprintf("Date range: %s to %s", min(clean_data$Date), max(clean_data$Date))
)

writeLines(cleaning_log, file.path(DIR_PROC, "cleaning_log.txt"))
cat(paste(cleaning_log, collapse = "\n"), "\n")

## ---- save-clean -------------------------------------------------------------
readr::write_csv(clean_data, file.path(DIR_PROC, "engagement_clean.csv"))
cat(sprintf("\n[01_preprocess] Clean data written to %s\n",
            file.path(DIR_PROC, "engagement_clean.csv")))
